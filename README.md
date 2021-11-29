# cmp-tabnine
TabNine source for [hrsh7th/nvim-cmp](https://github.com/hrsh7th/nvim-cmp)

# Install

Using plug:
   ```viml
   Plug 'tzachar/cmp-tabnine', { 'do': './install.sh' }
   ```

Using plug on windows:

	Plug 'tzachar/cmp-tabnine', { 'do': 'powershell ./install.ps1'}

Using [Packer](https://github.com/wbthomason/packer.nvim/):
   ```viml
return require("packer").startup(
	function(use)
		use "hrsh7th/nvim-cmp" --completion
		use {'tzachar/cmp-tabnine', run='./install.sh', requires = 'hrsh7th/nvim-cmp'}
	end
)
   ```
Using [Packer](https://github.com/wbthomason/packer.nvim/) on windows:
   ```viml
return require("packer").startup(
	function(use)
		use "hrsh7th/nvim-cmp" --completion
		use {'tzachar/cmp-tabnine', run='powershell ./install.ps1', requires = 'hrsh7th/nvim-cmp'}
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
	run_on_every_keystroke = true;
	snippet_placeholder = '..';
	ignored_file_types = { -- default is not to ignore
		-- uncomment to ignore in lua:
		-- lua = true
	};
})
```

## `max_lines`

How many lines of buffer context to pass to TabNine

## `max_num_results`

How many results to return

## `sort`

Sort results by returned priority


## `run_on_every_keystroke`

Generate new completion items on every keystroke. For more info, check out [#18](https://github.com/tzachar/cmp-tabnine//issues/18)

## `snippet_placeholder`

Indicates where the cursor will be placed in case a completion item is a
snippet. Any string is accepted.

For this to work properly, you need to setup snippet support for `nvim-cmp`.

## `ignored_file_types` `(table: <string:bool>)`
Which file types to ignore. For example:
```
ignored_file_types = {
	html = true;
}
```
will make `cmp-tabnine` not offer completions when `vim.bo.filetype` is `html`.


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
