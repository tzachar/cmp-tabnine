local cmp = require'cmp'
local api = vim.api
local fn = vim.fn
local conf = require('cmp_tabnine.config')

local function dump(...)
    local objects = vim.tbl_map(vim.inspect, {...})
    print(unpack(objects))
end

local function json_decode(data)
	local status, result = pcall(vim.fn.json_decode, data)
	if status then
		return result
	else
		return nil, result
	end
end

local function get_path_separator()
    if ((fn.has('win64') == 1) or (fn.has('win32') == 1)) then return '\\' end
    return '/'
end

local function escape_tabstop_sign(str)
  return str:gsub("%$", "\\$")
end

local function script_path()
   local str = debug.getinfo(2, "S").source:sub(2)
   return str:match("(.*" .. get_path_separator() .. ")")
end

local function get_parent_dir(path)
    local separator = get_path_separator()
    local pattern = "^(.+)" .. separator
    -- if path has separator at end, remove it
    path = path:gsub(separator .. '*$', '')
    local parent_dir = path:match(pattern) .. separator
    return parent_dir
end

-- do this once on init, otherwise on restart this dows not work
local binaries_folder = get_parent_dir(get_parent_dir(script_path())) .. 'binaries'

-- locate the binary here, as expand is relative to the calling script name
local function binary()
	local versions_folders = fn.globpath(binaries_folder, '*', false, true)
	local versions = {}
	for _, path in ipairs(versions_folders) do
		for version in string.gmatch(path, '/([0-9.]+)$') do
			if version then
				table.insert(versions, {path=path, version=version})
			end
		end
	end
	table.sort(versions, function (a, b) return a.version < b.version end)
	local latest = versions[#versions]
	if not latest then
		vim.notify('cmp-tabnine: Cannot find installed TabNine. Please run install.sh')
		return
	end

	local platform = nil
	local arch, _ = string.gsub(fn.system('uname -m'), '\n$', '')
	if fn.has('win32') == 1 then
		platform = 'i686-pc-windows-gnu'
	elseif fn.has('win64') == 1 then
		platform = 'x86_64-pc-windows-gnu'
	elseif fn.has('mac') == 1 then
		if arch == 'arm64' then
			platform = 'aarch64-apple-darwin'
		else
			platform = arch .. '-apple-darwin'
		end
	elseif fn.has('unix') == 1 then
		platform = arch .. '-unknown-linux-musl'
	end
	return latest.path .. '/' .. platform .. '/' .. 'TabNine'
end

local Source = {
	callback = nil;
	job = 0;
}

function Source.new()
	local self = setmetatable({}, { __index = Source })
	self._on_exit(0, 0)
	return self
end


Source.is_available = function()
	return (Source.job ~= 0)
end


Source.get_debug_name = function()
	return 'TabNine'
end

-- pass ctx message from do_complete to on_output
-- FIXME: It may lead to unmatch of ctx list because on_stdout may not be called
Source.ctx_list = {}

Source._do_complete = function(ctx)
	if Source.job == 0 then
		return
	end
	local max_lines = conf:get('max_lines')
	local cursor = ctx.context.cursor
	local cur_line = ctx.context.cursor_line
	local cur_line_before = string.sub(cur_line, 1, cursor.col - 1)
	local cur_line_after = string.sub(cur_line, cursor.col) -- include current character

	local region_includes_beginning = false
	local region_includes_end = false
	if cursor.line - max_lines <= 1 then region_includes_beginning = true end
	if cursor.line + max_lines >= fn['line']('$') then region_includes_end = true end

	local lines_before = api.nvim_buf_get_lines(0, cursor.line - max_lines , cursor.line - 1, false)
	table.insert(lines_before, cur_line_before)
	local before = table.concat(lines_before, "\n")

	local lines_after = api.nvim_buf_get_lines(0, cursor.line + 1, cursor.line + max_lines, false)
	table.insert(lines_after, 1, cur_line_after)
	local after = table.concat(lines_after, "\n")

	local req = {}
	req.version = "3.3.0"
	req.request = {
		Autocomplete = {
			before = before,
			after = after,
			region_includes_beginning = region_includes_beginning,
			region_includes_end = region_includes_end,
			filename = fn["expand"]("%:p"),
			max_num_results = conf:get('max_num_results')
		}
	}

	table.insert(Source.ctx_list, ctx)
	fn.chansend(Source.job, fn.json_encode(req) .. "\n")
end

--- complete
function Source.complete(self, ctx, callback)
	Source.callback = callback
	Source._do_complete(ctx)
end

Source._on_exit = function(_, code)
	-- restart..
	if code == 143 then
		-- nvim is exiting. do not restart
		return
	end

	local bin = binary()
	if not bin then
		return
	end
	Source.ctx_list = {}
	Source.job = fn.jobstart({bin, '--client=cmp.vim'}, {
		on_stderr = nil;
		on_exit = Source._on_exit;
		on_stdout = Source._on_stdout;
	})
end

Source._on_stdout = function(_, data, _)
      -- {
      --   "old_prefix": "wo",
      --   "results": [
      --     {
      --       "new_prefix": "world",
      --       "old_suffix": "",
      --       "new_suffix": "",
      --       "detail": "64%"
      --     }
      --   ],
      --   "user_message": [],
      --   "docs": []
      -- }
	-- check that we have a context.
	if #Source.ctx_list == 0 then
		return
	end
	local items = {}
	local old_prefix = ""
	local show_strength = conf:get('show_prediction_strength')
	local base_priority = conf:get('priority')

	local ctx = table.remove(Source.ctx_list, 1)
	local cursor = ctx.context.cursor

	for _, jd in ipairs(data) do
		if jd ~= nil and jd ~= '' then
			local response = json_decode(jd)
			-- dump(response)
			if response == nil then
				-- the _on_exit callback should restart the server
				-- fn.jobstop(Source.job)
				dump('TabNine: json decode error: ', jd)
			else
				local results = response.results
				old_prefix = response.old_prefix

				if results ~= nil then
					for _, result in ipairs(results) do
						local newText = result.new_prefix .. result.new_suffix

						local old_suffix = result.old_suffix
						if string.sub(old_suffix, -1) == "\n" then
							old_suffix = string.sub(old_suffix, 1, -2)
						end

						local item = {
							label = newText;
							filterText = newText;
							data = result;
							textEdit = {
								range = {
									start = { line = cursor.line, character = cursor.col - #old_prefix - 1 },
									['end'] = {  line = cursor.line, character = cursor.col  + #old_suffix - 1 };
								};
								newText = newText;
							};
							sortText = newText;
						}
						-- This is a hack fix for cmp not displaying items of TabNine::config_dir, version, etc. because their
						-- completion items get scores of 0 in the matching algorithm
						if #old_prefix == 0 then
							item['filterText'] = string.sub(ctx.context.cursor_before_line, ctx.offset) .. newText
						end

						if #result.new_suffix > 0 then
							item["insertTextFormat"] = cmp.lsp.InsertTextFormat.Snippet
							local snippet = escape_tabstop_sign(result.new_prefix) .. '$1' .. escape_tabstop_sign(result.new_suffix)
							item["textEdit"].newText = snippet .. '$0'
							if conf:get('snippet_placeholder') then
								item["label"] = snippet:gsub('$1', conf:get('snippet_placeholder'))
							end
						end

						if result.detail ~= nil then
							local percent = tonumber(string.sub(result.detail, 0, -2))
							if percent ~= nil then
								item['priority'] = base_priority + percent * 0.001
								item['labelDetails'] = {
									detail = result.detail
								}
								item['sortText'] = string.format("%02d", 100 - percent) .. item['sortText']
							else
								item['detail'] = result.detail
							end
						end
						if result.kind then
							item['kind'] = result.kind
						end
						if result.documentation then
							item['documentation'] = result.documentation
						end
						if result.deprecated then
							item['deprecated'] = result.deprecated
						end
						table.insert(items, item)
					end
				else
					dump('no results:', jd)
				end
			end
		end
	end

	-- sort by returned importance b4 limiting number of results
	table.sort(items, function(a, b)
		if not a.priority then
			return false
		elseif not b.priority then
			return true
		else
			return (a.priority > b.priority)
		end
	end)

	items = {unpack(items, 1, conf:get('max_num_results'))}
	--
	-- now, if we have a callback, send results
	if Source.callback then
		Source.callback({
			items = items,
			isIncomplete = conf:get('run_on_every_keystroke'),
		})
	end
	Source.callback = nil;
end

return Source
