local map = vim.keymap.set
local function bind(lhs, rhs, desc, mode) map(mode or "n", lhs, rhs, { desc = desc }) end
local review = require("config.review")
local function cwd() return review.root() or vim.fn.getcwd() end

bind("<Esc>", "<Cmd>nohlsearch<CR>", "Clear search highlight")
bind("<C-s>", "<Cmd>write<CR><Esc>", "Save file", { "n", "i", "x" })
bind("<leader><space>", function() Snacks.picker.files({ cwd = cwd() }) end, "Find files")
bind("<C-p>", function() Snacks.picker.files({ cwd = cwd() }) end, "Find files")
bind("<leader>/", function() Snacks.picker.grep({ cwd = cwd() }) end, "Search project text")
bind("<leader>,", function() Snacks.picker.buffers() end, "Switch buffer")
bind("<leader>:", function() Snacks.picker.commands() end, "Command palette")
bind("<leader>?", function() Snacks.picker.keymaps() end, "Search all shortcuts")
bind("<leader>e", function() Snacks.explorer({ cwd = cwd() }) end, "Toggle file explorer")
bind("<leader>E", function() Snacks.explorer.reveal() end, "Reveal current file in explorer")
bind("<leader>ff", function() Snacks.picker.files({ cwd = cwd() }) end, "Find files")
bind("<leader>fF", function() Snacks.picker.files({ cwd = cwd(), ignored = true }) end, "Find files including ignored")
bind("<leader>fr", function() Snacks.picker.recent({ filter = { cwd = true } }) end, "Recent project files")
bind("<leader>fy", function()
  local path = vim.fs.relpath(cwd(), vim.api.nvim_buf_get_name(0)) or vim.api.nvim_buf_get_name(0)
  vim.fn.setreg("+", path .. ":" .. vim.fn.line("."))
  vim.notify("Copied " .. path .. ":" .. vim.fn.line("."))
end, "Copy file:line for agent feedback")
bind("<leader>sg", function() Snacks.picker.grep({ cwd = cwd() }) end, "Search project text")
bind("<leader>sw", function() Snacks.picker.grep_word({ cwd = cwd() }) end, "Search word / selection", { "n", "x" })
bind("<leader>sr", function() require("grug-far").open({ prefills = { paths = cwd() } }) end, "Project search and replace")
bind("<leader>sh", function() Snacks.picker.help() end, "Search help")
bind("<leader>sn", function() Snacks.notifier.show_history() end, "Notification history")
bind("<leader>bd", function() Snacks.bufdelete() end, "Close buffer, keep layout")
bind("<S-h>", "<Cmd>bprevious<CR>", "Previous buffer")
bind("<S-l>", "<Cmd>bnext<CR>", "Next buffer")
bind("<leader>sq", function() Snacks.picker.qflist() end, "Quickfix list")
bind("<leader>uw", "<Cmd>set wrap!<CR>", "Toggle line wrapping")
bind("<leader>un", "<Cmd>set relativenumber!<CR>", "Toggle relative numbers")
bind("<leader>uz", function() Snacks.zen.zoom() end, "Zoom current window")
bind("<leader>ut", function()
  vim.o.background = vim.o.background == "dark" and "light" or "dark"
  vim.cmd.colorscheme("neon")
end, "Toggle neon light / dark")
bind("<leader>tt", function() Snacks.terminal(nil, { cwd = cwd() }) end, "Project terminal")
bind("<Esc><Esc>", "<C-\\><C-n>", "Leave terminal mode", "t")

bind("<leader>rr", function() review.open() end, "Review uncommitted changes")
bind("<leader>rs", function() review.open(nil, nil, { "--cached" }) end, "Review staged changes")
bind("<leader>rb", review.branches, "Review branch against base")
bind("<leader>rB", review.base, "Review against named base")
bind("<leader>rc", review.commits, "Find commit and review patch")
bind("<leader>rh", function() review.history(true) end, "Current file history")
bind("<leader>rH", function() review.history(false) end, "Repository history")
bind("<leader>rm", review.checkpoint, "Mark HEAD before agent run")
bind("<leader>ra", review.since_checkpoint, "Review since agent checkpoint")
bind("<leader>rq", "<Cmd>DiffviewClose<CR>", "Close review")
bind("<leader>ru", "<Cmd>checktime<CR><Cmd>DiffviewRefresh<CR>", "Refresh review from disk")

bind("<leader>tn", "<Cmd>tabnew<CR>", "New tab")
bind("<leader>tc", function()
  local lib = package.loaded["diffview.lib"]
  if lib and lib.get_current_view() then
    require("diffview").close()
  else
    vim.cmd.tabclose()
  end
end, "Close tab")
bind("<leader>th", "<Cmd>tabprevious<CR>", "Previous tab")
bind("<leader>tl", "<Cmd>tabnext<CR>", "Next tab")

bind("<leader>ww", "<C-w>w", "Next window")
bind("<leader>wv", "<C-w>v", "Split window right")
bind("<leader>ws", "<C-w>s", "Split window below")
bind("<leader>wc", "<C-w>c", "Close window")
for _, key in ipairs({ "h", "j", "k", "l" }) do
  bind("<leader>w" .. key, "<C-w>" .. key, "Focus window " .. key)
end
bind("<leader>gd", function() Snacks.picker.git_status({ cwd = cwd() }) end, "Changed files with preview")
bind("<leader>gg", function()
  if vim.fn.executable("lazygit") == 0 then
    vim.notify("Install lazygit: brew install lazygit. Space r r opens the built-in review workflow.", vim.log.levels.WARN)
    return
  end
  Snacks.lazygit({ cwd = cwd() })
end, "Lazygit: branches / commits / worktrees")

-- Cross multiplexer pane boundaries only at a Neovim window edge.
for key, direction in pairs({ h = "L", j = "D", k = "U", l = "R" }) do
  bind("<C-" .. key .. ">", function()
    local win = vim.api.nvim_get_current_win()
    vim.cmd.wincmd(key)
    if win == vim.api.nvim_get_current_win() then
      if vim.env.HERDR_PANE_ID then
        local directions = { L = "left", D = "down", U = "up", R = "right" }
        vim.system({ "herdr", "pane", "focus", "--pane", vim.env.HERDR_PANE_ID,
          "--direction", directions[direction] }, {}, function() end)
      elseif vim.env.TMUX then
        vim.system({ "tmux", "select-pane", "-" .. direction }, {}, function() end)
      end
    end
  end, "Navigate " .. key)
end
bind("<", "<gv", "Indent left", "x")
bind(">", ">gv", "Indent right", "x")
