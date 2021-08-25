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
