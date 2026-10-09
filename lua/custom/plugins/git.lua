-- Everything git, in one file.
--
-- Three layers, each answering a different question:
--
--   per-hunk   gitsigns          "what changed on this line / in this hunk?"
--   review     diffview          "what changed across this whole branch?"
--   search     telescope/neo-tree "which file, commit or branch do I want?"
--
-- plus the native-diff rendering options both gitsigns and diffview draw with,
-- and the blame virtual text.
--
-- The complete keymap set:
--
--   REVIEW (diffview)                     SEARCH (telescope / neo-tree)
--   <leader>gd  uncommitted changes       <leader>gs  changed files (picker)
--   <leader>gD  branch vs its base        <leader>gc  commits
--   <leader>gr  revision range…           <leader>gb  branches
--   <leader>gh  file history              <leader>ge  changed files (tree)
--   <leader>gH  repo history
--   <leader>gx  close the diff view
--
--   PER-HUNK (gitsigns, buffer-local)     TOGGLES
--   ]c / [c     next / prev change        <leader>tb  inline blame
--   <leader>hs  stage hunk (n and v)      <leader>tD  show deleted
--   <leader>hr  reset hunk (n and v)
--   <leader>hS  stage buffer
--   <leader>hR  reset buffer
--   <leader>hu  undo stage hunk
--   <leader>hp  preview hunk
--   <leader>hb  blame line
--   <leader>hd  diff against index
--   <leader>hD  diff against last commit
--
-- Inside a diffview tab the plugin's own buffer-local defaults apply:
-- <Tab>/<S-Tab> next and previous file, <leader>e focus the file panel,
-- <leader>b toggle it, `g?` for the full list.

-- ---------------------------------------------------------------------------
-- Native diff rendering
-- ---------------------------------------------------------------------------

--- Configure how Neovim computes and draws diffs. This is not specific to any
--- one plugin — gitsigns' `diffthis` and every diffview window render through
--- it — so it only needs to run once, at startup. It is parked on the gitsigns
--- spec's `init` below because gitsigns is the git plugin that always loads.
local function setup_diff_rendering()
  -- Set as a whole rather than appended, so there is one place to read the
  -- answer from and no dependence on what the Neovim default happens to be in
  -- a given version. See `:help 'diffopt'`.
  vim.opt.diffopt = {
    'internal', -- use the built-in diff library, not an external `diff` binary
    'filler', -- show filler lines so both sides stay vertically aligned
    'closeoff', -- leave diff mode when the last other diff window closes
    'vertical', -- `:diffsplit` opens side-by-side, not stacked
    'algorithm:histogram', -- better hunk boundaries than the default myers
    'indent-heuristic', -- shift hunks so they line up with indentation
    'linematch:60', -- pair up changed lines within a hunk, so the highlight
    -- lands on the words that changed instead of the whole line
    'context:6', -- unchanged lines kept visible around each hunk when folded
    'foldcolumn:1',
  }

  -- Filler lines (the "this side has nothing here" rows) render as a hatched
  -- column instead of a solid block of dashes.
  vim.opt.fillchars:append { diff = '╱' }

  -- Folding in diff windows.
  --  `folding.lua` sets a global `foldlevel` of 99 so normal files open fully
  --  unfolded. In a diff that is the wrong default: it means scrolling through
  --  hundreds of identical lines to find the handful that changed. Diff windows
  --  get `foldlevel = 0` instead, which collapses everything outside the
  --  `context:6` lines around each hunk. `zR` opens it all back up, and dropping
  --  this autocmd restores the old behaviour.
  vim.api.nvim_create_autocmd('OptionSet', {
    group = vim.api.nvim_create_augroup('kickstart-diff-folds', { clear = true }),
    pattern = 'diff',
    desc = 'Collapse unchanged regions when a window enters diff mode',
    callback = function()
      if vim.wo.diff then
        vim.wo.foldmethod = 'diff'
        vim.wo.foldlevel = 0
        vim.wo.wrap = false
      else
        -- Back to the normal-file defaults when the window leaves diff mode.
        vim.wo.foldlevel = 99
        vim.wo.wrap = vim.o.wrap
      end
    end,
  })
end

-- ---------------------------------------------------------------------------
-- diffview helpers
-- ---------------------------------------------------------------------------

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

--- Open `:DiffviewOpen <args>`, or close the view if one is already up, so the
--- same key both enters and leaves the review.
local function toggle_diffview(args)
  local ok, lib = pcall(require, 'diffview.lib')
  if ok and lib.get_current_view() ~= nil then
    vim.cmd 'DiffviewClose'
  else
    vim.cmd('DiffviewOpen ' .. (args or ''))
  end
end

-- ---------------------------------------------------------------------------
-- Specs
-- ---------------------------------------------------------------------------
--
-- Several of these are `keys`/`opts` additions to plugins declared in
-- `init.lua`; lazy.nvim merges specs for the same plugin, so they extend the
-- existing configuration rather than replacing it.

return {
  { -- Per-hunk: gutter signs, staging, blame, and the native diff options
    'lewis6991/gitsigns.nvim',
    init = setup_diff_rendering,
    opts = {
      signs = {
        add = { text = '+' },
        change = { text = '~' },
        delete = { text = '_' },
        topdelete = { text = '‾' },
        changedelete = { text = '~' },
      },
      on_attach = function(bufnr)
        local gitsigns = require 'gitsigns'

        local function map(mode, l, r, opts)
          opts = opts or {}
          opts.buffer = bufnr
          vim.keymap.set(mode, l, r, opts)
        end

        -- Navigation
        map('n', ']c', function()
          if vim.wo.diff then
            vim.cmd.normal { ']c', bang = true }
          else
            gitsigns.nav_hunk 'next'
          end
        end, { desc = 'Jump to next git [c]hange' })

        map('n', '[c', function()
          if vim.wo.diff then
            vim.cmd.normal { '[c', bang = true }
          else
            gitsigns.nav_hunk 'prev'
          end
        end, { desc = 'Jump to previous git [c]hange' })

        -- Actions
        -- visual mode
        map('v', '<leader>hs', function()
          gitsigns.stage_hunk { vim.fn.line '.', vim.fn.line 'v' }
        end, { desc = 'git [s]tage hunk' })
        map('v', '<leader>hr', function()
          gitsigns.reset_hunk { vim.fn.line '.', vim.fn.line 'v' }
        end, { desc = 'git [r]eset hunk' })
        -- normal mode
        map('n', '<leader>hs', gitsigns.stage_hunk, { desc = 'git [s]tage hunk' })
        map('n', '<leader>hr', gitsigns.reset_hunk, { desc = 'git [r]eset hunk' })
        map('n', '<leader>hS', gitsigns.stage_buffer, { desc = 'git [S]tage buffer' })
        map('n', '<leader>hu', gitsigns.stage_hunk, { desc = 'git [u]ndo stage hunk' })
        map('n', '<leader>hR', gitsigns.reset_buffer, { desc = 'git [R]eset buffer' })
        map('n', '<leader>hp', gitsigns.preview_hunk, { desc = 'git [p]review hunk' })
        map('n', '<leader>hb', gitsigns.blame_line, { desc = 'git [b]lame line' })
        map('n', '<leader>hd', gitsigns.diffthis, { desc = 'git [d]iff against index' })
        map('n', '<leader>hD', function()
          gitsigns.diffthis '@'
        end, { desc = 'git [D]iff against last commit' })
        -- Toggles
        map('n', '<leader>tb', gitsigns.toggle_current_line_blame, { desc = '[T]oggle git show [b]lame line' })
        map('n', '<leader>tD', gitsigns.preview_hunk_inline, { desc = '[T]oggle git show [D]eleted' })
      end,
    },
  },

  { -- Review: every changed file in one panel, side-by-side, plus a merge tool
    'sindrets/diffview.nvim',
    dependencies = { 'nvim-lua/plenary.nvim' },
    cmd = { 'DiffviewOpen', 'DiffviewClose', 'DiffviewFileHistory', 'DiffviewToggleFiles', 'DiffviewFocusFiles' },
    keys = {
      {
        '<leader>gd',
        function()
          toggle_diffview()
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
          toggle_diffview(base .. '...HEAD --imply-local')
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
        -- OptionSet autocmd in `setup_diff_rendering` can miss them. Re-apply.
        diff_buf_win_enter = function(_, winid)
          vim.wo[winid].foldlevel = 0
          vim.wo[winid].wrap = false
          vim.wo[winid].list = false
        end,
      },
    },
  },

  { -- Search: fuzzy pickers over changed files, commits and branches
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

  { -- Search: the changed files as a sidebar tree
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

  { -- Blame as virtual text at the end of the current line
    'f-person/git-blame.nvim',
    event = 'VeryLazy',
    opts = {
      enabled = true,
      message_template = ' <summary> • <date> • <author> • <<sha>>',
      date_format = '%m-%d-%Y %H:%M:%S',
      virtual_text_column = 1,
    },
  },
}
