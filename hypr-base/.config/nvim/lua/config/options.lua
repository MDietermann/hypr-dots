-- Options are automatically loaded before lazy.nvim startup
-- Default options that are always set: https://github.com/LazyVim/LazyVim/blob/main/lua/lazyvim/config/options.lua
-- Add any additional options here

-- theme-switch integration: advertise a nvim server per pid
local sock = (vim.env.XDG_RUNTIME_DIR or "/tmp") .. "/nvim-" .. vim.fn.getpid()
pcall(vim.fn.serverstart, sock)
