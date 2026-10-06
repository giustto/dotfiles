local group = vim.api.nvim_create_augroup("NeonWorkflow", { clear = true })
vim.api.nvim_create_autocmd("TextYankPost", {
  group = group, callback = function() vim.hl.on_yank({ timeout = 150 }) end,
})
vim.api.nvim_create_autocmd({ "FocusGained", "TermClose", "TermLeave" }, {
  group = group,
  callback = function()
    if vim.fn.mode() ~= "c" then vim.cmd.checktime() end
  end,
})

-- External tools can change the working tree while Neovim stays focused.
-- Diffview already refreshes on writes and tab entry; poll only while a review is open.
local review_timer
local function refresh_review()
  local lib = package.loaded["diffview.lib"]
  local view = lib and lib.get_current_view()
  if not view or not view.ready or not view.update_files then return end
  if vim.fn.mode() == "c" then return end
  vim.cmd.checktime()
  view:update_files()
end
vim.api.nvim_create_autocmd("User", {
  group = group, pattern = "DiffviewViewOpened",
  callback = function()
    if review_timer then return end
    local timer = vim.uv.new_timer()
    review_timer = timer
    timer:start(3000, 3000, vim.schedule_wrap(function()
      if review_timer ~= timer then return end
      local lib = package.loaded["diffview.lib"]
      if not lib or #lib.views == 0 then
        timer:stop()
        timer:close()
        review_timer = nil
        return
      end
      refresh_review()
    end))
  end,
})
vim.api.nvim_create_autocmd("FocusGained", { group = group, callback = refresh_review })
vim.api.nvim_create_autocmd("VimLeavePre", {
  group = group,
  callback = function()
    if review_timer then review_timer:stop(); review_timer:close(); review_timer = nil end
  end,
})
vim.api.nvim_create_autocmd("BufReadPost", {
  group = group,
  callback = function(ev)
    local mark = vim.api.nvim_buf_get_mark(ev.buf, '"')
    if mark[1] > 0 and mark[1] <= vim.api.nvim_buf_line_count(ev.buf) then
      pcall(vim.api.nvim_win_set_cursor, 0, mark)
    end
  end,
})
vim.api.nvim_create_autocmd("VimEnter", {
  group = group,
  callback = function()
    if #vim.api.nvim_list_uis() == 0 or vim.fn.argc() ~= 0 or vim.bo.buftype ~= "" then return end
    vim.schedule(function() Snacks.explorer({ cwd = vim.fn.getcwd() }) end)
  end,
})
vim.api.nvim_create_autocmd("FileType", {
  group = group,
  callback = function(ev)
    if vim.bo[ev.buf].buftype == "" then pcall(vim.treesitter.start, ev.buf) end
  end,
})
