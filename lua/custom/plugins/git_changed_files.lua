-- "Show me every file I changed" — without installing anything new.
--
-- Both of these come from plugins that are already in the config, they just
-- had no keymap pointing at them:
--
--   <leader>gs  telescope `git_status` — fuzzy list of changed files with a
--               live diff in the preview pane. <Tab> stages/unstages the file
--               under the cursor, <CR> opens it (then <leader>hd for the
--               side-by-side diff).
--   <leader>ge  neo-tree `git_status` — the changed files as a tree in the
--               sidebar, closest thing to VSCode's Source Control panel.
--   <leader>gc  telescope `git_commits` — repo history, <CR> checks out.
--   <leader>gf  telescope `git_bcommits` — history of the current file only.
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
        '<leader>gf',
        function()
          require('telescope.builtin').git_bcommits()
        end,
        desc = '[G]it commits for this [F]ile',
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
