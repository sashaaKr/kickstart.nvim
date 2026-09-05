-- Fuzzy-find your way into git: changed files, commits, branches.
--
-- These are the *search* half of the git keymaps — pick a thing from a list.
-- The *review* half lives in `diffview.lua` (<leader>gd / gD / gh / gH), and
-- the per-hunk half lives in `kickstart/plugins/gitsigns.lua` (<leader>h…).
--
-- The whole <leader>g namespace, in one place:
--
--   gd  diffview: uncommitted changes          gs  telescope: changed files
--   gD  diffview: branch vs base               gc  telescope: commits
--   gr  diffview: revision range…              gb  telescope: branches
--   gh  diffview: file history                 ge  neo-tree: changed files tree
--   gH  diffview: repo history
--   gx  diffview: close
--
-- Note that these are `keys` entries on plugins declared elsewhere; lazy.nvim
-- merges specs for the same plugin, so this only adds keymaps and does not
-- re-declare or override the existing telescope / neo-tree configuration.

return {
  {
    'nvim-telescope/telescope.nvim',
    keys = {
      {
        '<leader>gs',
        function()
          require('telescope.builtin').git_status()
        end,
        -- <Tab> stages/unstages the file under the cursor, <CR> opens it.
        desc = '[G]it [S]tatus (changed files)',
      },
      {
        '<leader>gc',
        function()
          require('telescope.builtin').git_commits()
        end,
        desc = '[G]it [C]ommits',
      },
      {
        '<leader>gb',
        function()
          require('telescope.builtin').git_branches()
        end,
        desc = '[G]it [B]ranches',
      },
    },
  },

  {
    'nvim-neo-tree/neo-tree.nvim',
    keys = {
      {
        '<leader>ge',
        ':Neotree git_status right toggle<CR>',
        desc = '[G]it changed files [E]xplorer',
        silent = true,
      },
    },
  },
}
