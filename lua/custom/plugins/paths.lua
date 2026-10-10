-- Copy the current file's path to the clipboard.
--
--   <leader>yp  path relative to the repo root   lua/custom/plugins/git.lua
--   <leader>yP  absolute path                    /home/me/.config/nvim/lua/…
--   <leader>yn  file name only                   git.lua
--   <leader>yl  relative path + line             lua/custom/plugins/git.lua:42
--               (on a selection: the range)      lua/custom/plugins/git.lua:42-57
--
-- "Relative" means relative to the git root when there is one, so the path is
-- the same one a reviewer sees on the forge no matter where Neovim was started.
-- Outside a repo it falls back to the working directory.
--
-- For a link to the line on GitHub / GitLab instead, see `<leader>gy` in
-- `git.lua`.

--- The current buffer's file, or nil (with a warning) for scratch buffers,
--- terminals, file trees and the like.
---@return string|nil
local function current_file()
  local file = vim.api.nvim_buf_get_name(0)
  if file == '' or vim.bo.buftype ~= '' then
    vim.notify('Not a file buffer', vim.log.levels.WARN)
    return nil
  end
  return file
end

---@param file string
---@return string
local function relative_path(file)
  local root = vim.fs.root(file, '.git')
  if root then
    return file:sub(#root + 2)
  end
  return vim.fn.fnamemodify(file, ':.')
end

local function copy(text)
  vim.fn.setreg('+', text)
  vim.fn.setreg('"', text)
  vim.notify('Copied ' .. text)
end

--- Build a keymap callback that copies `format(file)` for the current buffer.
---@param format fun(file: string): string
local function copier(format)
  return function()
    local file = current_file()
    if file then
      copy(format(file))
    end
  end
end

vim.keymap.set('n', '<leader>yp', copier(relative_path), { desc = '[Y]ank relative [p]ath' })
vim.keymap.set(
  'n',
  '<leader>yP',
  copier(function(file)
    return file
  end),
  { desc = '[Y]ank absolute [P]ath' }
)
vim.keymap.set(
  'n',
  '<leader>yn',
  copier(function(file)
    return vim.fn.fnamemodify(file, ':t')
  end),
  { desc = '[Y]ank file [n]ame' }
)
vim.keymap.set(
  { 'n', 'v' },
  '<leader>yl',
  copier(function(file)
    local first, last = vim.fn.line 'v', vim.fn.line '.'
    if vim.fn.mode():find '^[vV\22]' then
      -- Leave visual mode so the selection does not linger after copying.
      vim.api.nvim_feedkeys(vim.keycode '<Esc>', 'nx', false)
    else
      first = last
    end
    first, last = math.min(first, last), math.max(first, last)
    local range = first == last and tostring(first) or (first .. '-' .. last)
    return relative_path(file) .. ':' .. range
  end),
  { desc = '[Y]ank path + [l]ine' }
)

return {
  { -- Label the group in the which-key popup
    'folke/which-key.nvim',
    opts = function(_, opts)
      opts.spec = opts.spec or {}
      table.insert(opts.spec, { '<leader>y', group = '[Y]ank path', mode = { 'n', 'v' } })
    end,
  },
}
