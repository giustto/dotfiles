local path = vim.fn.stdpath("data") .. "/lazy/lazy.nvim"
if not vim.uv.fs_stat(path) then
  local result = vim.system({
    "git", "clone", "--filter=blob:none", "--branch=stable",
    "https://github.com/folke/lazy.nvim.git", path,
  }, { text = true }):wait()
  if result.code ~= 0 then
    error("Could not install lazy.nvim:\n" .. (result.stderr or "Check Git and your network connection"))
  end
end
vim.opt.rtp:prepend(path)
require("lazy").setup({
  spec = { { import = "plugins" } },
  defaults = { lazy = false },
  checker = { enabled = false },
  change_detection = { notify = false },
  install = { colorscheme = { "neon" } },
  ui = { border = "rounded" },
  performance = { rtp = { disabled_plugins = { "netrwPlugin" } } },
})
