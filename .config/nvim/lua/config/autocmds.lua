local group = vim.api.nvim_create_augroup("NeonWorkflow", { clear = true })
vim.api.nvim_create_autocmd("TextYankPost", {
  group = group,
  callback = function()
    vim.hl.on_yank({ timeout = 150 })
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
    if #vim.api.nvim_list_uis() == 0 or vim.fn.argc() ~= 0 or vim.bo.buftype ~= "" then
      return
    end
    vim.schedule(function()
      Snacks.explorer({ cwd = vim.fn.getcwd() })
    end)
  end,
})
vim.api.nvim_create_autocmd("FileType", {
  group = group,
  callback = function(ev)
    if vim.bo[ev.buf].buftype == "" then
      pcall(vim.treesitter.start, ev.buf)
    end
  end,
})
