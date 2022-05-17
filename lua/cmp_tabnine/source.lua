local cmp = require('cmp')
local api = vim.api
local fn = vim.fn
local conf = require('cmp_tabnine.config')

local function dump(...)
  local objects = vim.tbl_map(vim.inspect, { ... })
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

local function is_win()
  return package.config:sub(1, 1) == '\\'
end

local function get_path_separator()
  if is_win() then
    return '\\'
  end
  return '/'
end

local function escape_tabstop_sign(str)
  return str:gsub('%$', '\\$')
end

local function build_snippet(prefix, placeholder, suffix, add_final_tabstop)
  local snippet = escape_tabstop_sign(prefix) .. placeholder .. escape_tabstop_sign(suffix)
  if add_final_tabstop then
    return snippet .. '$0'
  else
    return snippet
  end
end

local function script_path()
  local str = debug.getinfo(2, 'S').source:sub(2)
  if is_win() then
    str = str:gsub('/', '\\')
  end
  return str:match('(.*' .. get_path_separator() .. ')')
end

local function get_parent_dir(path)
  local separator = get_path_separator()
  local pattern = '^(.+)' .. separator
  -- if path has separator at end, remove it
  path = path:gsub(separator .. '*$', '')
  local parent_dir = path:match(pattern) .. separator
  return parent_dir
end

-- do this once on init, otherwise on restart this dows not work
local binaries_folder = get_parent_dir(get_parent_dir(script_path())) .. 'binaries'

-- this function is taken from https://github.com/yasuoka/stralnumcmp/blob/master/stralnumcmp.lua
local function stralnumcmp(a, b)
  local a0, b0, an, bn, as, bs, c
  a0 = a
  b0 = b
  while a:len() > 0 and b:len() > 0 do
    an = a:match('^%d+')
    bn = b:match('^%d+')
    as = an or a:match('^%D+')
    bs = bn or b:match('^%D+')

    if an and bn then
      c = tonumber(an) - tonumber(bn)
    else
      c = (as < bs) and -1 or ((as > bs) and 1 or 0)
    end
    if c ~= 0 then
      return c
    end
    a = a:sub((an and an:len() or as:len()) + 1)
    b = b:sub((bn and bn:len() or bs:len()) + 1)
  end
  return (a0:len() - b0:len())
end

-- locate the binary here, as expand is relative to the calling script name
local function binary()
  local versions_folders = fn.globpath(binaries_folder, '*', false, true)
  local versions = {}
  for _, path in ipairs(versions_folders) do
    for version in string.gmatch(path, '([0-9.]+)$') do
      if version then
        table.insert(versions, { path = path, version = version })
      end
    end
  end
  table.sort(versions, function(a, b)
    return stralnumcmp(a.version, b.version) < 0
  end)
  local latest = versions[#versions]
  if not latest then
    vim.notify(string.format('cmp-tabnine: Cannot find installed TabNine. Please run install.%s', (is_win() and 'ps1' or 'sh')))
    return
  end

  local platform = nil

  if fn.has('win64') == 1 then
    platform = 'x86_64-pc-windows-gnu'
  elseif fn.has('win32') == 1 then
    platform = 'i686-pc-windows-gnu'
  else
    local arch, _ = string.gsub(fn.system({'uname',  '-m'}), '\n$', '')
    if fn.has('mac') == 1 then
      if arch == 'arm64' then
        platform = 'aarch64-apple-darwin'
      else
        platform = arch .. '-apple-darwin'
      end
    elseif fn.has('unix') == 1 then
      platform = arch .. '-unknown-linux-musl'
    end
  end
  return latest.path .. '/' .. platform .. '/' .. 'TabNine'
end

local Source = {
  job = 0,
  pending = {},
}

function Source.new()
  local self = setmetatable({}, { __index = Source })
  self._on_exit(0, 0)
  return self
end

Source.open_tabnine_hub = function(self)
  local req = {}
  req.version = '3.3.0'
  req.request = {
    Configuration = {
      quiet = false,
    },
  }

  if self == nil then
    -- this happens when nvim < 0.7 and vim.api.nvim_add_user_command does not exist
    self = Source
  end
  pcall(fn.chansend, self.job, fn.json_encode(req) .. '\n')
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
  local cur_line_before = string.sub(cur_line, 1, cursor.col - 1)
  local cur_line_after = string.sub(cur_line, cursor.col) -- include current character

  local region_includes_beginning = false
  local region_includes_end = false
  if cursor.line - max_lines <= 1 then
    region_includes_beginning = true
  end
  if cursor.line + max_lines >= fn['line']('$') then
    region_includes_end = true
  end

  local lines_before = api.nvim_buf_get_lines(0, cursor.line - max_lines, cursor.line - 1, false)
  table.insert(lines_before, cur_line_before)
  local before = table.concat(lines_before, '\n')

  local lines_after = api.nvim_buf_get_lines(0, cursor.line + 1, cursor.line + max_lines, false)
  table.insert(lines_after, 1, cur_line_after)
  local after = table.concat(lines_after, '\n')

  local req = {}
  req.version = '3.3.0'
  req.request = {
    Autocomplete = {
      before = before,
      after = after,
      region_includes_beginning = region_includes_beginning,
      region_includes_end = region_includes_end,
      -- filename = fn["expand"]("%:p"),
      filename = vim.uri_from_bufnr(0):gsub('file://', ''),
      max_num_results = conf:get('max_num_results'),
      correlation_id = ctx.context.id,
    },
  }

  -- fn.chansend(Source.job, fn.json_encode(req) .. "\n")
  -- if there is an error, e.g., the channel is dead, we expect on_exit will be
  -- called in the future and restart the server
  -- we use pcall as we do not want to spam the user with error messages
  pcall(fn.chansend, Source.job, fn.json_encode(req) .. '\n')
end

--- complete
function Source.complete(self, ctx, callback)
  if conf:get('ignored_file_types')[vim.bo.filetype] then
    callback()
    return
  end
  Source.pending[ctx.context.id] = { ctx = ctx, callback = callback }
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
  Source.pending = {}
  Source.job = fn.jobstart({ bin, '--client=cmp.vim' }, {
    on_stderr = nil,
    on_exit = Source._on_exit,
    on_stdout = Source._on_stdout,
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
  local show_strength = conf:get('show_prediction_strength')
  local base_priority = conf:get('priority')

  for _, jd in ipairs(data) do
    if jd ~= nil and jd ~= '' then
      local response = json_decode(jd)
      -- dump(response)
      local id = (response or {}).correlation_id
      if Source.pending[id] == nil then
        -- the _on_exit callback should restart the server
        -- fn.jobstop(Source.job)
        if response == nil then
          dump('TabNine: json decode error: ', jd)
        end
      else
        local ctx = Source.pending[id].ctx
        local callback = Source.pending[id].callback
        Source.pending[id] = nil

        local cursor = ctx.context.cursor

        local items = {}
        local old_prefix = response.old_prefix
        local results = response.results

        if results ~= nil then
          for _, result in ipairs(results) do
            local newText = result.new_prefix .. result.new_suffix

            local old_suffix = result.old_suffix
            if string.sub(old_suffix, -1) == '\n' then
              old_suffix = string.sub(old_suffix, 1, -2)
            end

            local range = {
              start = { line = cursor.line, character = cursor.col - #old_prefix - 1 },
              ['end'] = { line = cursor.line, character = cursor.col + #old_suffix - 1 },
            }

            local item = {
              label = newText,
              filterText = newText,
              data = result,
              textEdit = {
                newText = newText,
                insert = range, -- May be better to exclude the trailing part of old_suffix since it's 'replaced'?
                replace = range,
              },
              sortText = newText,
              dup = 0,
            }
            -- This is a hack fix for cmp not displaying items of TabNine::config_dir, version, etc. because their
            -- completion items get scores of 0 in the matching algorithm
            if #old_prefix == 0 then
              item['filterText'] = string.sub(ctx.context.cursor_before_line, ctx.offset) .. newText
            end

            if #result.new_suffix > 0 then
              item['insertTextFormat'] = cmp.lsp.InsertTextFormat.Snippet
              item['label'] = build_snippet(result.new_prefix, conf:get('snippet_placeholder'), result.new_suffix, false)
              item['textEdit'].newText = build_snippet(result.new_prefix, '$1', result.new_suffix, true)
            end

            if result.detail ~= nil then
              local percent = tonumber(string.sub(result.detail, 0, -2))
              if percent ~= nil then
                item['priority'] = base_priority + percent * 0.001
                if show_strength then
                    item['labelDetails'] = {
                      detail = result.detail,
                    }
                end
                item['sortText'] = string.format('%02d', 100 - percent) .. item['sortText']
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

        items = { unpack(items, 1, conf:get('max_num_results')) }
        callback({
          items = items,
          isIncomplete = conf:get('run_on_every_keystroke'),
        })
      end
    end
  end
end

return Source
