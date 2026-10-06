vim.g.mapleader = " "
vim.g.maplocalleader = ","

require("config.options")
require("config.theme").setup()
require("config.lazy")
require("config.keymaps")
require("config.autocmds")
require("config.responsive").setup()
