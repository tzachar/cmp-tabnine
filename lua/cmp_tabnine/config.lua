local M = {}

local conf_defaults = {
  max_lines = 1000,
  max_num_results = 20,
  sort = true,
  priority = 5000,
  min_percent = 0,
  run_on_every_keystroke = true,
  snippet_placeholder = '..',
  ignored_file_types = { -- default is not to ignore
    -- uncomment to ignore in lua:
    -- lua = true
  },
}

function M:setup(params)
  if params == nil then
    vim.api.nvim_err_writeln('Bad call to cmp_tabnine.config.setup; Make sure to use setup:(params) -- note the use of a colon (:)')
    params = self or {}
  end
  for k, v in pairs(params or {}) do
    conf_defaults[k] = v
  end
end

function M:get(what)
  return conf_defaults[what]
end

return M
