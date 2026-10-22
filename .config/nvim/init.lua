vim.g.mapleader = " "
vim.g.maplocalleader = ","

require("config.options")
require("config.theme").setup()
require("config.lazy")
require("config.keymaps")
require("config.autocmds")
require("config.reading").setup()
require("config.languages").setup()
require("config.task_review").setup()
require("config.refresh").setup()
require("config.responsive").setup()
