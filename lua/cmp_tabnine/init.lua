local cmp = require('cmp')
local source = require('cmp_tabnine.source')

local M = {}

M.setup = function()
  vim.schedule(function()
    cmp.register_source('cmp_tabnine', source.new())
  end)
end

return M
