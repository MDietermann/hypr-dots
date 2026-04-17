return {
  -- rose-pine for theme-sakura
  { "rose-pine/neovim", name = "rose-pine" },

  -- Configure LazyVim to use it
  {
    "LazyVim/LazyVim",
    opts = {
      colorscheme = "rose-pine",
    },
  },
}
