local cmp = require('cmp')
local source = require('cmp_tabnine.source')

local M = {}

M.prefetch = function(self, file_path, count)
  count = (count or 1)
  if self.tabnine_source == nil and count < 5 then
    -- not initialized yet
    vim.schedule(function()
      self:prefetch(file_path, count + 1)
    end)
  else
    self.tabnine_source:prefetch(file_path)
  end
end

M.setup = function()
  vim.schedule(function()
    M.tabnine_source = source.new()
    cmp.register_source('cmp_tabnine', M.tabnine_source)

    if vim.api.nvim_create_user_command ~= nil then
      vim.api.nvim_create_user_command('CmpTabnineHub', function()
        M.tabnine_source:open_tabnine_hub(false)
      end, { force = true })

      vim.api.nvim_create_user_command('CmpTabnineHubUrl', function()
        vim.notify(M.tabnine_source:get_hub_url())
      end, { force = true })

      vim.api.nvim_create_user_command('CmpTabninePrefetch', function(args)
        M:prefetch(args.args)
      end, { force = true, nargs = 1, complete = 'file' })
    else
      -- set self to nil to use latest source
      vim.cmd([[command! CmpTabnineHub lua require('cmp_tabnine.source').open_tabnine_hub(nil, false)]])
      vim.cmd([[command! CmpTabnineHubUrl lua print(require('cmp_tabnine.source').get_hub_url(nil))]])
      vim.cmd([[command! -nargs=1 -complete=file CmpTabninePrefetch lua require('cmp_tabnine'):prefetch(<q-args>)]])
    end
  end)
end

return M
