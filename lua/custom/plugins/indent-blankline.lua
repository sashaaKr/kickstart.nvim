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
      -- Pin the guide colors: the colorscheme's scope highlight blends into the
      -- background, which made the current scope's guide vanish instead of stand out.
      local hooks = require 'ibl.hooks'
      hooks.register(hooks.type.HIGHLIGHT_SETUP, function()
        vim.api.nvim_set_hl(0, 'IblIndent', { fg = '#3c4048' })
        vim.api.nvim_set_hl(0, 'IblWhitespace', { fg = '#3c4048' })
        vim.api.nvim_set_hl(0, 'IblScope', { fg = '#7b8496' })
      end)
      require('ibl').setup(opts)
    end,
  },
}
