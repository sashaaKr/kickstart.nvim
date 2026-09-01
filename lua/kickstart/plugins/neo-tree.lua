-- Neo-tree is a Neovim plugin to browse the file system
-- https://github.com/nvim-neo-tree/neo-tree.nvim

return {
  'nvim-neo-tree/neo-tree.nvim',
  version = '*',
  dependencies = {
    'nvim-lua/plenary.nvim',
    'nvim-tree/nvim-web-devicons', -- not strictly required, but recommended
    'MunifTanjim/nui.nvim',
  },
  lazy = false,
  keys = {
    { '\\', ':Neotree reveal<CR>', desc = 'NeoTree reveal', silent = true },
  },
  opts = {
    window = {
      position = 'right',
      mappings = {
        -- Defined here rather than under `filesystem` so that `\` closes the
        -- window from every source, not just the file tree. Neo-tree merges
        -- these top-level mappings into each source; a source-level
        -- `window.mappings` table only applies to that one source.
        ['\\'] = 'close_window',
      },
    },
  },
}
