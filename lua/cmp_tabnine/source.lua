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


-- do this once on init, otherwise on restart this dows not work
local binaries_folder = fn.expand('<sfile>:p:h:h:h') .. '/binaries'

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


Source._do_complete = function(ctx)
	if Source.job == 0 then
		return
	end
	local max_lines = conf:get('max_lines')
	local cursor = ctx.context.cursor
	local cur_line = ctx.context.cursor_line
	local cur_line_before = string.sub(cur_line, 0, cursor.col)
	local cur_line_after = string.sub(cur_line, cursor.col + 1) -- include current character

	local region_includes_beginning = false
	local region_includes_end = false
	if cursor.line - max_lines <= 1 then region_includes_beginning = true end
	if cursor.line + max_lines >= fn['line']('$') then region_includes_end = true end

	local lines_before = api.nvim_buf_get_lines(0, cursor.line - max_lines , cursor.line - 1, false)
	table.insert(lines_before, cur_line_before)
	local before = table.concat(lines_before, "\n")

	local lines_after = api.nvim_buf_get_lines(0, cursor.line, cursor.line + max_lines, false)
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

	fn.chansend(Source.job, fn.json_encode(req) .. "\n")
end

--- complete
function Source.complete(self, ctx, callback)
	Source.callback = callback
	Source._do_complete(ctx)
end

Source._on_err = function(_, _, _)
end

Source._on_exit = function(_, code)
	-- restart..
	if code == 143 then
		-- nvim is exiting. do not restart
		return
	end

	Source.job = fn.jobstart({binary(), '--client=cmp.vim'}, {
		on_stderr = Source._on_stderr;
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
	-- dump(data)
	local items = {}
	local old_prefix = ""
	local show_strength = conf:get('show_prediction_strength')
	local base_priority = conf:get('priority')

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
						local item = {
							label = result.new_prefix;
							filterText = result.new_prefix;
							insertText = result.new_prefix;
							data = result;
							sortText = (result.details or '') .. result.new_prefix;
						}
						if result.detail ~= nil then
							local percent = tonumber(string.sub(result.detail, 0, -2))
							if percent ~= nil then
								item['priority'] = base_priority + percent * 0.001
								item['labelDetails'] = {
									detail = result.detail
								}
								item['details'] = result.detail
							end
						end
						if result.kind then
							item['kind'] = result.kind
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
		Source.callback(items)
	end
	Source.callback = nil;
end

function Source:get_trigger_characters(params)
  return { ':', '.',  '(', '[', }
end

return Source
