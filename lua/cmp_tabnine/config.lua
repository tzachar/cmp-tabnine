local M = {}

local conf_defaults = {
  max_lines = 1000,
  max_num_results = 20,
  sort = true,
  priority = 5000,
  show_prediction_strength = false,
  run_on_every_keystroke = true,
  snippet_placeholder = '..',
  ignored_file_types = { -- default is not to ignore
    -- uncomment to ignore in lua:
    -- lua = true
  },
}

function M:setup(params)
  for k, v in pairs(params) do
    conf_defaults[k] = v
  end
end

function M:get(what)
  return conf_defaults[what]
end

return M
