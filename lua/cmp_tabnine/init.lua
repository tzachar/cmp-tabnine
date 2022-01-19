local cmp = require('cmp')
local source = require('cmp_tabnine.source')

local M = {}

M.setup = function()
  vim.schedule(function()
    tabnine_source = source.new()
    cmp.register_source('cmp_tabnine', tabnine_source)
    vim.cmd [[command! CmpTabnineHub lua tabnine_source.open_tabnine_hub()]]
  end)
end

return M
