local cmp = require'cmp'
local api = vim.api
local fn = vim.fn
--

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


--- _get_paths
local function get_paths(root, paths)
	local c = root
	for _, path in ipairs(paths) do
		c = c[path]
		if not c then
			return nil
		end
	end
	return c
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

local conf_defaults = {
	max_lines = 1000;
	max_num_results = 20;
	sort = false;
	priority = 5000;
	show_prediction_strength = true;
	ignore_pattern = '';
}

-- TODO: add setup function
local function conf(key)
	-- for now, we use conf_defaults
	local c = conf_defaults
	local value = get_paths(c, {'source', 'tabnine', key})
	if value ~= nil then
		return value
	elseif conf_defaults[key] ~= nil then
		return conf_defaults[key]
	else
		error()
	end
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


--- get_metadata
function Source.get_metadata(_)
	return {
		priority = 5000;
		menu = '[TN]';
		sort = conf('sort');
	}
end

Source._do_complete = function()
	-- print('do complete')
	if Source.job == 0 then
		return
	end
	local max_lines = conf('max_lines')

	local cursor=api.nvim_win_get_cursor(0)
	local cur_line = api.nvim_get_current_line()
	local cur_line_before = string.sub(cur_line, 0, cursor[2])
	local cur_line_after = string.sub(cur_line, cursor[2]+1) -- include current character

	local region_includes_beginning = false
	local region_includes_end = false
	if cursor[1] - max_lines <= 1 then region_includes_beginning = true end
	if cursor[1] + max_lines >= fn['line']('$') then region_includes_end = true end

	local lines_before = api.nvim_buf_get_lines(0, cursor[1] - max_lines , cursor[1]-1, false)
	table.insert(lines_before, cur_line_before)
	local before = table.concat(lines_before, "\n")

	local lines_after = api.nvim_buf_get_lines(0, cursor[1], cursor[1] + max_lines, false)
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
			max_num_results = conf('max_num_results')
		}
	}

	fn.chansend(Source.job, fn.json_encode(req) .. "\n")
end

--- complete
function Source.complete(self, request, callback)
	Source.callback = callback
	Source._do_complete()
	callback(nil)
end

Source._on_err = function(_, _, _)
end

Source._on_exit = function(_, code)
	-- restart..
	if code == 143 then
		-- nvim is exiting. do not restart
		return
	end

	Source.job = fn.jobstart({binary()}, {
		on_stderr = Source._on_stderr;
		on_exit = Source._on_exit;
		on_stdout = Source._on_stdout;
	})
end

local function documentation(completion_item)
	local document = {}
	local show = false
	-- table.insert(document, '```' .. args.context.filetype)
	table.insert(document, '```')
	-- only add the detail when its not a % value
	if completion_item and completion_item.detail and #completion_item.detail > 3 then
		table.insert(document, completion_item.detail)
		table.insert(document, ' ')
		show = true
	end

	if completion_item.documentation then
		table.insert(document, completion_item.documentation)
		show = true
	end
	table.insert(document, '```')
	return document
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
	local show_strength = conf('show_prediction_strength')
	local base_priority = conf('priority')

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
							filerText = result.new_prefix;
							insertText = result.new_prefix;
							details = '';
							labelDetails = {
								description = '';
							};
							user_data = result;
							documentation = documentation(result);
							sortText = (result.details or '') .. result.new_prefix;
						}
						if result.detail ~= nil then
							local percent = tonumber(string.sub(result.detail, 0, -2))
							if percent ~= nil then
								item['priority'] = base_priority + percent * 0.001
								item.labelDetails.description = item.labelDetails.description .. ' ' .. result.detail
								item.label = item.label .. ' ' .. result.detail
							end
						end
						item.labelDetails.description = item.labelDetails.description .. ' [TN]'
						item.label = item.label .. ' [TN]'
						-- item['kind'] = vim.lsp.protocol.CompletionItemKind[result.kind] or nil;
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

	items = {unpack(items, 1, conf('max_num_results'))}
	--
	-- now, if we have a callback, send results
	if Source.callback then
		if #items == 0 then
			return
		end
		Source.callback(items)
	end
	Source.callback = nil;
end

return Source
