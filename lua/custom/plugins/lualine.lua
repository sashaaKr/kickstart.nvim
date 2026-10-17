-- Statusline: lualine, replacing kickstart's default mini.statusline.
--
-- Only one plugin can own the statusline — mini.statusline re-sets it on every
-- window switch — so its setup call is removed from the mini.nvim spec in
-- `init.lua`.

return {
  {
    'nvim-lualine/lualine.nvim',
    event = 'VeryLazy',
    dependencies = { { 'nvim-tree/nvim-web-devicons', enabled = vim.g.have_nerd_font } },
    opts = {
      options = {
        theme = 'auto',
        icons_enabled = vim.g.have_nerd_font,
        globalstatus = true,
      },
      sections = {
        lualine_a = { 'mode' },
        lualine_b = { 'branch', 'diff', 'diagnostics' },
        lualine_c = { { 'filename', path = 1 } },
        lualine_x = { 'encoding', 'fileformat', 'filetype' },
        lualine_y = { 'progress' },
        lualine_z = { 'location' },
      },
      extensions = { 'neo-tree', 'lazy' },
    },
  },
}
