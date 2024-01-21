# cmp-tabnine
Tabnine source for [hrsh7th/nvim-cmp](https://github.com/hrsh7th/nvim-cmp)

# Install

## Dependencies

On Linux and Mac, you will need `curl` and `unzip` in your `$PATH`.

On windows, you just need powershell. If you get a `PSSecurityException` while
trying to install, try the following command in powershell:

```
Set-ExecutionPolicy -ExecutionPolicy RemoteSigned -Scope CurrentUser
```

For more information, see [about_Execution_Policies](https:/go.microsoft.com/fwlink/?LinkID=135170).

## Using a plugin manager

Using plug:
   ```viml
   Plug 'tzachar/cmp-tabnine', { 'do': './install.sh' }
   ```

Using plug on windows:
   ```viml
   Plug 'tzachar/cmp-tabnine', { 'do': 'powershell ./install.ps1' }
   ```

Using [Lazy](https://github.com/folke/lazy.nvim/):
   ```lua
return require("lazy").setup({
    {
        'tzachar/cmp-tabnine',
        build = './install.sh',
        dependencies = 'hrsh7th/nvim-cmp',
    }})
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
## Using NvChad
see [this issue](https://github.com/tzachar/cmp-tabnine/issues/47)

# Setup

```lua
local tabnine = require('cmp_tabnine.config')

tabnine:setup({
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

Please note the use of `:` instead of a `.`

## Configure Tabnine or Log in to Your Account

On [Tabnine Hub](#More-Commands)

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
			-- if you have lspkind installed, you can use it like
			-- in the following line:
	 		vim_item.kind = lspkind.symbolic(vim_item.kind, {mode = "symbol"})
	 		vim_item.menu = source_mapping[entry.source.name]
	 		if entry.source.name == "cmp_tabnine" then
                local detail = (entry.completion_item.labelDetails or {}).detail
	 			vim_item.kind = ""
	 			if detail and detail:find('.*%%.*') then
	 				vim_item.kind = vim_item.kind .. ' ' .. detail
	 			end

	 			if (entry.completion_item.data or {}).multiline then
	 				vim_item.kind = vim_item.kind .. ' ' .. '[ML]'
	 			end
	 		end
	 		local maxwidth = 80
	 		vim_item.abbr = string.sub(vim_item.abbr, 1, maxwidth)
	 		return vim_item
	  end,
	},
}
```

# Customize cmp highlight group

The highlight group is `CmpItemKindTabNine`, you can change it by:

```lua
vim.api.nvim_set_hl(0, "CmpItemKindTabNine", {fg ="#6CC644"})
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

# Prefetch

TabNine supports prefetching files, preprocessing them before users ask for
completions. Prefetching is supported through a command:

`:CmpTabninePrefetch file_path`

and also directly using lua:

```lua
require('cmp_tabnine'):prefetch(file_path)
```

The lua api can be used to prefetch a project, or a file on open:

```lua
local prefetch = vim.api.nvim_create_augroup("prefetch", {clear = true})

vim.api.nvim_create_autocmd('BufRead', {
  group = prefetch,
  pattern = '*.py',
  callback = function()
    require('cmp_tabnine'):prefetch(vim.fn.expand('%:p'))
  end
})
```

# Multi-Line suggestions

TabNine supports multi-line suggestions in Pro mode. If a suggestions is multi-line, we add
the `entry.completion_item.data.detail.multiline` flag to the completion entry
and the entire suggestion to the `documentation` property of the entry, such
that `cmp` will display the suggested lines in the documentation panel.

To enable multi-line completions, you should (a) have a Pro account and (b)
select either the hybrid or cloud completion models in the TabNine Hub.

Moreover, TabNine tends to suggest multi-line completions only on a new line
(usually after a comment describing what you are expecting to get). The easiest
way to trigger the completion is by manually invoking cmp on a new line.

Support for multi-line completions in cmp works only from version 4.4.213 of
TabNine (see [this issue](https://github.com/codota/tabnine-nvim/issues/6#issuecomment-1364655503)).

# More Commands

- `:CmpTabnineHub`: Open Tabnine Hub
- `:CmpTabnineHubUrl`: Show the link to Tabnine Hub
