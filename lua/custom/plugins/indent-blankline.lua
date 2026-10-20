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
    config = function(_, opts)
      -- Pin the guide colors. Both must stay readable on the CursorLine background
      -- (cyberdream: #3c4047), or the guides vanish on the line under the cursor.
      local hooks = require 'ibl.hooks'
      hooks.register(hooks.type.HIGHLIGHT_SETUP, function()
        vim.api.nvim_set_hl(0, 'IblIndent', { fg = '#5c6370' })
        vim.api.nvim_set_hl(0, 'IblWhitespace', { fg = '#5c6370' })
        vim.api.nvim_set_hl(0, 'IblScope', { fg = '#a0a8b7' })
      end)
      require('ibl').setup(opts)
    end,
  },
}
