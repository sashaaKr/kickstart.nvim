-- Git: review, search, blame, sharing, and how diffs are drawn.
--
-- Four layers, each answering a different question:
--
--   per-hunk   gitsigns          "what changed on this line / in this hunk?"
--   review     diffview          "what changed across this whole branch?"
--   search     telescope/neo-tree "which file, commit or branch do I want?"
--   share      gitlinker + forge "link to this line / where did it come from?"
--
-- This file owns the review, search and share layers, the blame virtual text,
-- and the native-diff rendering options that both gitsigns and diffview draw
-- with.
--
-- The per-hunk layer is kickstart's own: the gutter sign glyphs come from the
-- gitsigns spec in `init.lua`, and the `<leader>h…` hunk keymaps from
-- `lua/kickstart/plugins/gitsigns.lua`. Both are stock kickstart files, left
-- untouched so upstream updates merge cleanly — look there to change a hunk
-- mapping, and here for everything else. Their keymaps are listed below so
-- this header is still the full picture.
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
--   SHARE (browser / forge)
--   <leader>gy  copy permalink to line (n) or selected lines (v)
--   <leader>gY  open that permalink in the browser (n and v)
--   <leader>go  open the commit that last changed this line
--   <leader>gp  open the PR / MR that introduced this line
--
--   Copying the file's own path (<leader>y…) lives in `paths.lua`.
--
--   PER-HUNK (gitsigns, elsewhere)        TOGGLES (gitsigns, elsewhere)
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
--- it — so it only needs to run once, at startup. It is parked on the diffview
--- spec's `init` below, which is a spec this file owns outright.
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
-- Share helpers: from a line to its commit and PR / MR
-- ---------------------------------------------------------------------------

--- The commit that last touched the cursor line. Blamed against the buffer as
--- it is now (`--contents -`), so unsaved edits above the cursor do not shift
--- the line number onto a different line of the committed file.
---@return string|nil sha, string|nil err, string|nil cwd
local function blame_cursor_line()
  local file = vim.api.nvim_buf_get_name(0)
  if file == '' or vim.bo.buftype ~= '' then
    return nil, 'not a file buffer'
  end
  local cwd = vim.fs.dirname(file)
  local lnum = vim.api.nvim_win_get_cursor(0)[1]
  local contents = table.concat(vim.api.nvim_buf_get_lines(0, 0, -1, false), '\n') .. '\n'
  local result = vim
    .system({ 'git', 'blame', '--porcelain', '-L', lnum .. ',' .. lnum, '--contents', '-', '--', file }, { cwd = cwd, stdin = contents, text = true })
    :wait()
  if result.code ~= 0 then
    return nil, vim.trim(result.stderr ~= '' and result.stderr or 'git blame failed')
  end
  local sha = result.stdout:match '^(%x+)'
  if not sha or sha:match '^0+$' then
    return nil, 'this line is not committed yet'
  end
  return sha, nil, cwd
end

--- The `origin` remote as a browsable https URL, from any of the usual forms:
--- `git@host:owner/repo.git`, `ssh://git@host:22/owner/repo.git`,
--- `https://user@host/owner/repo.git`.
---@return string|nil
local function remote_web_url(cwd)
  local url = vim.trim(vim.fn.system { 'git', '-C', cwd, 'remote', 'get-url', 'origin' })
  if vim.v.shell_error ~= 0 or url == '' then
    return nil
  end
  url = url:gsub('%.git$', '')
  url = url:gsub('^git@([^:]+):', 'https://%1/')
  url = url:gsub('^ssh://[^@]*@([^/:]+)[:%d]*/', 'https://%1/')
  url = url:gsub('^(https?://)[^@/]*@', '%1')
  return url
end

---@return string|nil
local function commit_web_url(cwd, sha)
  local base = remote_web_url(cwd)
  if not base then
    return nil
  end
  if base:find 'gitlab' then
    return base .. '/-/commit/' .. sha
  elseif base:find 'bitbucket' then
    return base .. '/commits/' .. sha
  end
  return base .. '/commit/' .. sha
end

local function open_url(url)
  vim.ui.open(url)
  vim.notify('Opened ' .. url)
end

local function open_line_commit()
  local sha, err, cwd = blame_cursor_line()
  if not sha then
    return vim.notify('git: ' .. err, vim.log.levels.WARN)
  end
  local url = commit_web_url(cwd, sha)
  if not url then
    return vim.notify('git: no `origin` remote to open ' .. sha:sub(1, 8) .. ' on', vim.log.levels.WARN)
  end
  open_url(url)
end

--- Ask the forge which PR (GitHub, via `gh`) or MR (GitLab, via `glab`) the
--- line's commit belongs to. Works for merge, squash and rebase merges alike,
--- since it asks by commit rather than searching titles. Without the CLI, or
--- when nothing is found, it opens the commit page instead — both forges link
--- the PR / MR from there.
local function open_line_pr()
  local sha, err, cwd = blame_cursor_line()
  if not sha then
    return vim.notify('git: ' .. err, vim.log.levels.WARN)
  end
  local commit_url = commit_web_url(cwd, sha)
  local gitlab = (commit_url or ''):find 'gitlab' ~= nil
  local cli = gitlab and 'glab' or 'gh'
  local cmd = gitlab and { 'glab', 'api', 'projects/:id/repository/commits/' .. sha .. '/merge_requests' }
    or { 'gh', 'api', 'repos/{owner}/{repo}/commits/' .. sha .. '/pulls' }

  local function fallback(reason)
    if not commit_url then
      return vim.notify('git: ' .. reason, vim.log.levels.WARN)
    end
    vim.notify('git: ' .. reason .. ' — opening the commit instead', vim.log.levels.INFO)
    open_url(commit_url)
  end

  if vim.fn.executable(cli) == 0 then
    return fallback('`' .. cli .. '` is not installed')
  end

  vim.system(
    cmd,
    { cwd = cwd, text = true },
    vim.schedule_wrap(function(result)
      local ok, list = pcall(vim.json.decode, result.stdout or '')
      if result.code ~= 0 or not ok or type(list) ~= 'table' then
        return fallback('`' .. cli .. '` lookup failed')
      end
      -- A commit can sit in several PRs (e.g. one that was closed, then
      -- reopened as a new one); the merged one is the one that landed it.
      local pick = list[1]
      for _, pr in ipairs(list) do
        if pr.merged_at ~= vim.NIL and pr.merged_at ~= nil or pr.state == 'merged' then
          pick = pr
          break
        end
      end
      local url = pick and (pick.html_url or pick.web_url)
      if not url then
        return fallback('no ' .. (gitlab and 'MR' or 'PR') .. ' found for ' .. sha:sub(1, 8))
      end
      open_url(url)
    end)
  )
end

-- ---------------------------------------------------------------------------
-- Specs
-- ---------------------------------------------------------------------------
--
-- The telescope and neo-tree entries below are `keys` additions to plugins
-- declared in `init.lua`; lazy.nvim merges specs for the same plugin, so they
-- add keymaps without re-declaring or overriding those plugins' own setup.

return {
  { -- Review: every changed file in one panel, side-by-side, plus a merge tool
    'sindrets/diffview.nvim',
    dependencies = { 'nvim-lua/plenary.nvim' },
    -- lazy.nvim runs `init` for every spec during startup, including ones that
    -- are otherwise lazy-loaded, so the diff options are in place before the
    -- first diff is drawn without pulling diffview in at startup.
    init = setup_diff_rendering,
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

  { -- Share: permalinks to the current line or selection, and the commit and
    -- PR / MR behind the cursor line
    -- Pinned to the current commit, so the link keeps pointing at the same
    -- code after the branch moves on. The commit has to be pushed for the
    -- link to resolve for anyone else. Knows github.com, gitlab.com,
    -- bitbucket.org and codeberg; a self-hosted forge needs a router entry
    -- (see `:help gitlinker`).
    'linrongbin16/gitlinker.nvim',
    cmd = 'GitLink',
    opts = {},
    keys = {
      -- `<cmd>` rather than `:` keeps visual mode alive, which is how the
      -- plugin picks up the selected range.
      { '<leader>gy', '<cmd>GitLink<CR>', mode = { 'n', 'v' }, desc = '[G]it permalink: cop[Y]' },
      { '<leader>gY', '<cmd>GitLink!<CR>', mode = { 'n', 'v' }, desc = '[G]it permalink: open in browser' },
      -- These two use the helpers above, not gitlinker; they live here so the
      -- whole share layer is one spec.
      { '<leader>go', open_line_commit, desc = '[G]it [O]pen commit for this line' },
      { '<leader>gp', open_line_pr, desc = '[G]it open [P]R / MR for this line' },
    },
  },

  { -- Label `<leader>g` in visual mode too
    'folke/which-key.nvim',
    opts = function(_, opts)
      -- `<leader>g` is only labelled for normal mode in `init.lua`; the
      -- permalink keys also work on a selection.
      opts.spec = opts.spec or {}
      table.insert(opts.spec, { '<leader>g', group = '[G]it', mode = { 'n', 'v' } })
    end,
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
