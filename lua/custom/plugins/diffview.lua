-- A real review view for git changes.
--
-- gitsigns answers "what changed in *this file*". diffview answers "what
-- changed across the whole branch": a panel of every touched file on the left,
-- the side-by-side diff on the right, <Tab> to walk from file to file without
-- losing the view. It is also the merge tool — three-way, with one keystroke
-- per conflict side.
--
-- Entry points (all under <leader>g, see the `keys` table below):
--
--   <leader>gd  uncommitted changes (working tree + index vs HEAD)
--   <leader>gD  this branch vs its base — the "review my own PR" view
--   <leader>gr  arbitrary revision range, prompted
--   <leader>gh  history of the current file
--   <leader>gH  history of the whole repo
--   <leader>gh  (visual) history of the selected lines only
--   <leader>gx  close whatever diffview tab is open
--
-- Inside a diffview tab the buffer-local defaults apply: <Tab>/<S-Tab> next
-- and previous file, <leader>e focus the file panel, <leader>b toggle it, `g?`
-- for the full list.

--- Best guess at the branch this work forks off: what origin/HEAD points at,
--- else the first plausible name that actually exists.
---@return string|nil
local function base_branch()
  local head = vim.fn.systemlist { 'git', 'symbolic-ref', '--short', 'refs/remotes/origin/HEAD' }
  if vim.v.shell_error == 0 and head[1] and head[1] ~= '' then
    return vim.trim(head[1])
  end

  for _, name in ipairs { 'origin/main', 'origin/master', 'main', 'master' } do
    vim.fn.system { 'git', 'rev-parse', '--verify', '--quiet', name }
    if vim.v.shell_error == 0 then
      return name
    end
  end

  return nil
end

--- True when a diffview tab is currently open.
local function diffview_is_open()
  local ok, lib = pcall(require, 'diffview.lib')
  return ok and lib.get_current_view() ~= nil
end

--- Open `:DiffviewOpen <args>`, or close the view if one is already up, so the
--- same key both enters and leaves the review.
local function toggle(args)
  if diffview_is_open() then
    vim.cmd 'DiffviewClose'
  else
    vim.cmd('DiffviewOpen ' .. (args or ''))
  end
end

return {
  {
    'sindrets/diffview.nvim',
    dependencies = { 'nvim-lua/plenary.nvim' },
    cmd = { 'DiffviewOpen', 'DiffviewClose', 'DiffviewFileHistory', 'DiffviewToggleFiles', 'DiffviewFocusFiles' },
    keys = {
      {
        '<leader>gd',
        function()
          toggle()
        end,
        desc = '[G]it [D]iff (uncommitted changes)',
      },
      {
        '<leader>gD',
        function()
          local base = base_branch()
          if not base then
            vim.notify('diffview: no main/master branch found to compare against', vim.log.levels.WARN)
            return
          end
          -- `base...HEAD` diffs against the merge base, so commits that landed
          -- on the base branch after you forked do not show up as your changes.
          -- `--imply-local` makes the right-hand side the real files on disk,
          -- so edits made while reviewing are saved to the working tree.
          toggle(base .. '...HEAD --imply-local')
        end,
        desc = '[G]it [D]iff branch vs base (review my changes)',
      },
      {
        '<leader>gr',
        function()
          vim.ui.input({ prompt = 'DiffviewOpen ', default = 'HEAD~1' }, function(input)
            if input and input ~= '' then
              vim.cmd('DiffviewOpen ' .. input)
            end
          end)
        end,
        desc = '[G]it diff [R]evision range…',
      },
      {
        '<leader>gh',
        '<cmd>DiffviewFileHistory --follow %<CR>',
        desc = '[G]it file [H]istory (this file)',
      },
      {
        -- No `--follow` here: it is rejected when combined with a line range,
        -- which is what makes this the *selection's* history.
        '<leader>gh',
        "<Esc><cmd>'<,'>DiffviewFileHistory<CR>",
        mode = 'v',
        desc = '[G]it file [H]istory (selection)',
      },
      {
        '<leader>gH',
        '<cmd>DiffviewFileHistory<CR>',
        desc = '[G]it repo [H]istory',
      },
      {
        '<leader>gx',
        '<cmd>DiffviewClose<CR>',
        desc = '[G]it diff close (e[X]it)',
      },
    },
    opts = {
      enhanced_diff_hl = true, -- richer add/delete/change colours than plain diff mode
      view = {
        default = { layout = 'diff2_horizontal', winbar_info = true },
        -- Three-way for conflicts: OURS and THEIRS on top, the working-tree
        -- file you actually edit underneath.
        merge_tool = { layout = 'diff3_mixed', disable_diagnostics = true, winbar_info = true },
        file_history = { layout = 'diff2_horizontal', winbar_info = true },
      },
      file_panel = {
        listing_style = 'tree',
        tree_options = { flatten_dirs = true, folder_statuses = 'only_folded' },
        win_config = { position = 'left', width = 35 },
      },
      file_history_panel = {
        win_config = { position = 'bottom', height = 16 },
      },
      hooks = {
        -- The global `foldlevel = 99` from folding.lua also reaches diffview's
        -- windows, and diffview sets `diff` before the window exists, so the
        -- OptionSet autocmd in init.lua can miss them. Re-apply here.
        diff_buf_win_enter = function(_, winid)
          vim.wo[winid].foldlevel = 0
          vim.wo[winid].wrap = false
          vim.wo[winid].list = false
        end,
      },
    },
  },
}
