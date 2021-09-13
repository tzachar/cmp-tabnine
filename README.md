# cmp-tabnine
TabNine source for [hrsh7th/nvim-cmp](https://github.com/hrsh7th/nvim-cmp)

# Install

Using plug:
   ```viml
   Plug 'tzachar/cmp-tabnine', { 'do': './install.sh' }
   ```

Using [Packer](https://github.com/wbthomason/packer.nvim/):
   ```viml
return require("packer").startup(
	function(use)
		use "hrsh7th/nvim-cmp" --completion
		use {'tzachar/cmp-tabnine', run='./install.sh', requires = 'hrsh7th/nvim-cmp'}
	end
)
   ```

And later, enable the plugin:

   ```lua
require'cmp'.setup {
	sources = {
		{ name = 'cmp_tabnine' },
	},
}
   ```

# Setup

```lua
local tabnine = require('cmp_tabnine.config')
tabnine:setup({
        max_lines = 1000;
        max_num_results = 20;
        sort = true;
})
```

## `max_num_results`

How many lines of buffer context to pass to TabNine

## `max_num_results`

How many results to return

## `sort`

Sort results by returned priority

# Pretty Printing Menu Items 

You can use the following to pretty print the completion menu (requires
[lspkind](https://github.com/onsails/lspkind-nvim) and patched fonts
(https://www.nerdfonts.com)):

```lua
local lspkind = require('lspkind')

local source_mapping = {
	buffer = "[Buffer]",
	nvim_lsp = "[LSP]",
	nvim_lua = "[Lua]",
	cmp_tabnine = "[TN]",
	path = "[Path]",
}

require'cmp'.setup {
	sources = {
		{ name = 'cmp_tabnine' },
	},
	formatting = {
		format = function(entry, vim_item)
			vim_item.kind = lspkind.presets.default[vim_item.kind]
			local menu = source_mapping[entry.source.name]
			if entry.source.name == 'cmp_tabnine' then
				if entry.completion_item.data ~= nil and entry.completion_item.data.detail ~= nil then
					menu = entry.completion_item.data.detail .. ' ' .. menu
				end
				vim_item.kind = ''
			end
			vim_item.menu = menu
			return vim_item
		end
	},
}
```
