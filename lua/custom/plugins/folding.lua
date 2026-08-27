return {
  {
    'nvim-treesitter/nvim-treesitter',
    init = function()
      vim.opt.foldmethod = 'expr'
      vim.opt.foldexpr = 'v:lua.vim.treesitter.foldexpr()'
      -- Keep folding enabled, but start with everything unfolded so `za`
      -- only toggles the fold under the cursor instead of closing the file.
      vim.opt.foldenable = true
      vim.opt.foldlevel = 99
      vim.opt.foldlevelstart = 99
    end,
  },
}

