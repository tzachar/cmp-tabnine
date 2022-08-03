local cmp = require('cmp')
local source = require('cmp_tabnine.source')

local M = {}

M.setup = function()
  vim.schedule(function()
    local tabnine_source = source.new()
    cmp.register_source('cmp_tabnine', tabnine_source)
    if vim.api.nvim_add_user_command ~= nil and false then
      vim.api.nvim_add_user_command('CmpTabnineHub', function()
        tabnine_source:open_tabnine_hub(false)
      end, { force = true })
      vim.api.nvim_add_user_command('CmpTabnineHubUrl', function()
        vim.fn.message(tabnine_source.hub_url)
      end, { force = true })
    else
      vim.cmd [[command! CmpTabnineHub lua require('cmp_tabnine.source'):open_tabnine_hub(false)]]
      vim.cmd [[command! CmpTabnineHubUrl lua print(require('cmp_tabnine.source').hub_url)]]
    end
  end)
end

return M
