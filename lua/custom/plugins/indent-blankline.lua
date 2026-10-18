return {
  { -- Add indentation guides even on blank lines
    'lukas-reineke/indent-blankline.nvim',
    -- See `:help ibl`
    main = 'ibl',
    event = { 'BufReadPost', 'BufNewFile' },
    ---@module 'ibl'
    ---@type ibl.config
    opts = {
      indent = {
        char = '│',
        tab_char = '│',
      },
      -- Highlight the indent guide of the current treesitter scope.
      scope = {
        enabled = true,
        show_start = false,
        show_end = false,
      },
      exclude = {
        filetypes = {
          'help',
          'lazy',
          'mason',
          'neo-tree',
          'notify',
          'Trouble',
          'trouble',
          'toggleterm',
        },
      },
    },
  },
}
