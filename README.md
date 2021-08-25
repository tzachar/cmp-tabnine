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
		.
		.
		.
	},
}
   ```

# Setup

Coming...

<!-- 
# Completion Behavior

In general, as TabNine is a predictive completion engine, you would normally
want TabNine to suggest completions after every keypress. In some instances this
may be either prohibitive or annoying. To wor around it, you can use the
`ignore_pattern` config option. 
`ignore_pattern` is an RE specifying when not to suggest completions based on the character
before the cursor. For example, to not fire completions after an opening
bracket, set `ignore_pattern = '[(]'`. To disable this functionality, leave it
empty or set to an empty string.
-->

# Packer Issues

Sometimes, Packer fails to install the plugin (though cloning the repo
succeeds). Until this is resolved, perform the following:
```sh
cd ~/.local/share/nvim/site/pack/packer/start/cmp-tabnine
./install.sh
```

Change `~/.local/share/nvim/site/pack/packer/start/cmp-tabnine` to the path
Packer installs packages in your setup.
