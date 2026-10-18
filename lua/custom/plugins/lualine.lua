-- Statusline: lualine, replacing kickstart's default mini.statusline.
--
-- Only one plugin can own the statusline — mini.statusline re-sets it on every
-- window switch — so its setup call is removed from the mini.nvim spec in
-- `init.lua`.
--
-- Layout, drawn as rounded "pills" on a dark bar:
--
--   ( NORMAL )( branch ) +1 ~2 -3  path/to/file.go *    E1 W2  gopls ( go )( 74% 29:1 )
--
-- Colours come from the cyberdream palette (see `colors.lua`) so the bar
-- matches the editor. Encoding and file format are left out: they are almost
-- always utf-8/unix, and only show up when they are not.

-- cyberdream palette
local c = {
  bg = '#16181a',
  bg_alt = '#1e2124',
  bg_hl = '#3c4048',
  fg = '#ffffff',
  grey = '#7b8496',
  blue = '#5ea1ff',
  green = '#5eff6c',
  cyan = '#5ef1ff',
  red = '#ff6e5e',
  yellow = '#f1ff5e',
  magenta = '#ff5ef1',
  orange = '#ffbd5e',
  purple = '#bd5eff',
}

local function mode_theme(color)
  return {
    a = { fg = c.bg, bg = color, gui = 'bold' },
    b = { fg = c.fg, bg = c.bg_hl },
    c = { fg = c.grey, bg = c.bg_alt },
    z = { fg = c.bg, bg = color, gui = 'bold' },
  }
end

local theme = {
  normal = mode_theme(c.blue),
  insert = mode_theme(c.green),
  visual = mode_theme(c.magenta),
  replace = mode_theme(c.red),
  command = mode_theme(c.yellow),
  terminal = mode_theme(c.cyan),
  inactive = {
    a = { fg = c.grey, bg = c.bg_alt },
    b = { fg = c.grey, bg = c.bg_alt },
    c = { fg = c.grey, bg = c.bg_alt },
  },
}

local icons = vim.g.have_nerd_font

-- Names of the LSP servers attached to the current buffer, e.g. "gopls".
local function lsp_clients()
  local names = {}
  for _, client in ipairs(vim.lsp.get_clients { bufnr = 0 }) do
    table.insert(names, client.name)
  end
  if #names == 0 then
    return ''
  end
  return (icons and '\u{f013} ' or 'LSP: ') .. table.concat(names, ', ')
end

-- Only shown when it is not the usual utf-8 / unix.
local function file_encoding()
  local enc = vim.bo.fileencoding ~= '' and vim.bo.fileencoding or vim.o.encoding
  local fmt = vim.bo.fileformat
  local parts = {}
  if enc ~= 'utf-8' then
    table.insert(parts, enc)
  end
  if fmt ~= 'unix' then
    table.insert(parts, fmt)
  end
  return table.concat(parts, ' ')
end

return {
  {
    'nvim-lualine/lualine.nvim',
    event = 'VeryLazy',
    dependencies = { { 'nvim-tree/nvim-web-devicons', enabled = vim.g.have_nerd_font } },
    opts = {
      options = {
        theme = theme,
        icons_enabled = icons,
        globalstatus = true,
        component_separators = '',
        section_separators = icons and { left = '\u{e0b4}', right = '\u{e0b6}' } or '',
        disabled_filetypes = { statusline = { 'dashboard', 'alpha', 'snacks_dashboard' } },
      },
      sections = {
        lualine_a = {
          { 'mode', separator = icons and { left = '\u{e0b6}', right = '\u{e0b4}' } or nil, padding = { left = 0, right = 1 } },
        },
        lualine_b = {
          { 'branch', icon = icons and '\u{e0a0}' or nil },
        },
        lualine_c = {
          {
            'diff',
            symbols = icons and { added = '\u{f457} ', modified = '\u{f459} ', removed = '\u{f458} ' } or nil,
            diff_color = {
              added = { fg = c.green },
              modified = { fg = c.orange },
              removed = { fg = c.red },
            },
          },
          {
            'filename',
            path = 1,
            color = { fg = c.fg },
            symbols = { modified = '\u{25cf}', readonly = icons and '\u{f023}' or '[RO]', unnamed = '[No Name]', newfile = '[New]' },
          },
        },
        lualine_x = {
          {
            'diagnostics',
            symbols = icons and { error = '\u{f057} ', warn = '\u{f071} ', info = '\u{f05a} ', hint = '\u{f0335} ' } or nil,
            diagnostics_color = {
              error = { fg = c.red },
              warn = { fg = c.yellow },
              info = { fg = c.cyan },
              hint = { fg = c.purple },
            },
          },
          { lsp_clients, color = { fg = c.grey } },
          { file_encoding, color = { fg = c.orange } },
        },
        lualine_y = {
          { 'filetype' },
        },
        lualine_z = {
          { 'progress', separator = '' },
          { 'location', separator = icons and { right = '\u{e0b4}' } or nil, padding = { left = 1, right = 0 } },
        },
      },
      inactive_sections = {
        lualine_c = { { 'filename', path = 1 } },
        lualine_x = { 'location' },
      },
      extensions = { 'neo-tree', 'lazy' },
    },
  },
}
