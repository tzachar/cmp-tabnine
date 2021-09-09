local cmp = require('cmp')
local source = require('cmp_tabnine.source')

local M = {}

M.setup = function()
      cmp.register_source('cmp_tabnine', source.new())
end

return M
