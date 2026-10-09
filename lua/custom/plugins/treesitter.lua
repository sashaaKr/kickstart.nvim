-- Keep nvim-treesitter on the branch that `init.lua`'s spec actually targets.
--
-- `init.lua` configures treesitter with `main = 'nvim-treesitter.configs'`,
-- which is the API of the `master` branch. The plugin's default branch is now
-- `main` — a rewrite with no `nvim-treesitter.configs` module — so without this
-- pin the spec errors on every startup and you get no syntax highlighting
-- anywhere, diff views included.
--
-- This is a `branch` override on the spec declared in `init.lua`; lazy.nvim
-- merges specs for the same plugin, so it changes nothing else about it.
-- (`folding.lua` extends the same plugin with the fold settings.)
--
-- Note that `master` is archived upstream. The real fix is porting the spec in
-- `init.lua` to the `main` API, at which point this file should go away.

return {
  {
    'nvim-treesitter/nvim-treesitter',
    branch = 'master',
  },
}
