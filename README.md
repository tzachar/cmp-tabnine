# cmp-tabnine
Tabnine source for [hrsh7th/nvim-cmp](https://github.com/hrsh7th/nvim-cmp)

# Install

## Dependencies

On Linux and Mac, you will need `curl` and `unzip` in your `$PATH`.

On windows, you just need powershell.

## Using a plugin manager

Using plug:
   ```viml
   Plug 'tzachar/cmp-tabnine', { 'do': './install.sh' }
   ```

Using plug on windows:
   ```viml
   Plug 'tzachar/cmp-tabnine', { 'do': 'powershell ./install.ps1' }
   ```

Using [Packer](https://github.com/wbthomason/packer.nvim/):
   ```lua
return require("packer").startup(
	function(use)
		use "hrsh7th/nvim-cmp" --completion
		use {'tzachar/cmp-tabnine', run='./install.sh', requires = 'hrsh7th/nvim-cmp'}
	end
)
   ```
Using [Packer](https://github.com/wbthomason/packer.nvim/) on windows:
   ```lua
return require("packer").startup(
	function(use)
		use "hrsh7th/nvim-cmp" --completion
		use {'tzachar/cmp-tabnine', after = "nvim-cmp", run='powershell ./install.ps1', requires = 'hrsh7th/nvim-cmp'}
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

tabnine.setup({
	max_lines = 1000,
	max_num_results = 20,
	sort = true,
	run_on_every_keystroke = true,
	snippet_placeholder = '..',
	ignored_file_types = { 
		-- default is not to ignore
		-- uncomment to ignore in lua:
		-- lua = true
	},
	show_prediction_strength = false
})
```

## Configure Tabnine or Log in to Your Account

On [Tabnine Hub](#commands)

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
```lua
ignored_file_types = {
	html = true;
}
```
will make `cmp-tabnine` not offer completions when `vim.bo.filetype` is `html`.

## `show_prediction_strength`

When `show_prediction_strength` is true, `cmp-tabnine` will display
the prediction strength as a percentage by assigning `entry.completion_item.data.detail`.
This was previously the default behavior.

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

You can also use `lspkind`'s more advanced formmater, like the following:
```lua
  formatting = {
    format = lspkind.cmp_format({
      mode = "symbol_text", -- options: 'text', 'text_symbol', 'symbol_text', 'symbol'
      maxwidth = 40, -- prevent the popup from showing more than provided characters (e.g 50 will not show more than 50 characters)

      -- The function below will be called before any actual modifications from lspkind
      -- so that you can provide more controls on popup customization. (See [#30](https://github.com/onsails/lspkind-nvim/pull/30))
      before = function(entry, vim_item)
        vim_item.kind = lspkind.presets.default[vim_item.kind]

        local menu = source_mapping[entry.source.name]
        if entry.source.name == "cmp_tabnine" then
          if entry.completion_item.data ~= nil and entry.completion_item.data.detail ~= nil then
            menu = entry.completion_item.data.detail .. " " .. menu
          end
          vim_item.kind = ""
        end

        vim_item.menu = menu

        return vim_item
      end,
    }),
  },

```

# Sorting

`cmp-tabnine` adds a priority entry to each completion item,
which can be used to override `cmp`'s default sorting order:


```lua
local compare = require('cmp.config.compare')
cmp.setup({
  sorting = {
    priority_weight = 2,
    comparators = {
      require('cmp_tabnine.compare'),
      compare.offset,
      compare.exact,
      compare.score,
      compare.recently_used,
      compare.kind,
      compare.sort_text,
      compare.length,
      compare.order,
    },
  },
})
```

# Commands 

- `:CmpTabnineHub` Open Tabnine Hub
- `:CmpTabnineHubUrl` Show the link to Tanine Hub

