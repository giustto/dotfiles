local path = vim.fn.stdpath("data") .. "/lazy/lazy.nvim"
if not vim.uv.fs_stat(path) then
  local config_path = vim.uv.fs_realpath(debug.getinfo(1, "S").source:sub(2))
  local lock_path = vim.fs.dirname(config_path) .. "/../../lazy-lock.json"
  local lock = vim.json.decode(table.concat(vim.fn.readfile(lock_path), "\n"))
  local temp = path .. ".install-" .. vim.uv.os_getpid()
  vim.fn.mkdir(vim.fs.dirname(path), "p")
  local result = vim
    .system({
      "git",
      "clone",
      "--filter=blob:none",
      "--no-checkout",
      "https://github.com/folke/lazy.nvim.git",
      temp,
    }, { text = true })
    :wait()
  if result.code ~= 0 then
    vim.fn.delete(temp, "rf")
    error("Could not install lazy.nvim:\n" .. (result.stderr or "Check Git and your network connection"))
  end
  local checkout = vim
    .system({ "git", "-C", temp, "checkout", lock["lazy.nvim"].commit }, { text = true })
    :wait()
  if checkout.code ~= 0 then
    vim.fn.delete(temp, "rf")
    error("Could not select pinned lazy.nvim: " .. checkout.stderr)
  end
  assert(vim.uv.fs_rename(temp, path))
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
