local o = vim.opt
o.termguicolors = true
o.number = true
o.relativenumber = true
o.signcolumn = "yes"
o.cursorline = true
o.wrap = false
o.scrolloff = 5
o.sidescrolloff = 8
o.splitright = true
o.splitbelow = true
o.splitkeep = "screen"
o.laststatus = 3
o.showtabline = 1
o.tabline = "%!v:lua.require'config.tabline'.render()"
o.showmode = false
o.mouse = ""
o.clipboard = "unnamedplus"
o.ignorecase = true
o.smartcase = true
o.inccommand = "split"
o.updatetime = 250
o.timeoutlen = 350
o.undofile = true
o.autoread = true
o.confirm = true
o.expandtab = true
o.shiftwidth = 2
o.tabstop = 2
o.smartindent = true
o.winborder = "rounded"
o.list = true
o.listchars = { tab = "» ", trail = "·", nbsp = "␣" }
o.fillchars = { eob = " ", diff = "╱" }
o.diffopt = { "internal", "filler", "closeoff", "linematch:60", "algorithm:histogram", "indent-heuristic" }
o.grepprg = "rg --vimgrep --smart-case --hidden --glob !.git"
o.shortmess:append("I")

vim.diagnostic.config({
  severity_sort = true,
  virtual_text = false,
  underline = true,
  float = { border = "rounded", source = true },
  signs = { text = { [1] = "●", [2] = "●", [3] = "●", [4] = "●" } },
})
