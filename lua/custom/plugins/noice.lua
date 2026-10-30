return {
  {
    'folke/noice.nvim',
    event = 'VeryLazy',
    dependencies = { 'MunifTanjim/nui.nvim' },
    opts = {
      lsp = {
        -- Render LSP hover/docs markdown through Treesitter (nicer code blocks, no raw `---`)
        override = {
          ['vim.lsp.util.convert_input_to_markdown_lines'] = true,
          ['vim.lsp.util.stylize_markdown'] = true,
        },
        -- fidget.nvim already shows LSP progress
        progress = { enabled = false },
        -- blink.cmp already shows signature help
        signature = { enabled = false },
      },
      presets = {
        bottom_search = true, -- classic cmdline at the bottom for / and ?
        command_palette = true, -- cmdline and popupmenu together at the top
        long_message_to_split = true, -- long messages go to a split
        lsp_doc_border = true, -- border around hover docs and signature help
      },
    },
    keys = {
      { '<leader>sm', '<cmd>Noice telescope<CR>', desc = '[S]earch Noice [M]essages' },
    },
  },
}
