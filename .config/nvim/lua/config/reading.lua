local M = {}
local tabs = {}

-- Diffview reapplies window options when changing files and layouts.
function M.diff_window(_, win)
  vim.wo[win].wrap = vim.t.neon_diff_wrap ~= false
  vim.wo[win].linebreak = true
  vim.wo[win].breakindent = true
  vim.wo[win].scrollbind = true
  vim.wo[win].cursorbind = true
end

function M.toggle_wrap()
  local wrap = not vim.wo.wrap
  if vim.wo.diff then
    vim.t.neon_diff_wrap = wrap
    for _, win in ipairs(vim.api.nvim_tabpage_list_wins(0)) do
      if vim.wo[win].diff then
        vim.wo[win].wrap = wrap
      end
    end
    vim.cmd("syncbind")
  else
    vim.wo.wrap = wrap
  end
end

local function eligible(win)
  return vim.bo[vim.api.nvim_win_get_buf(win)].buftype == ""
    and not vim.wo[win].diff
    and vim.api.nvim_win_get_config(win).relative == ""
end

local function restore(win, options)
  if vim.api.nvim_win_is_valid(win) then
    vim.wo[win].scrollbind, vim.wo[win].cursorbind = options.scrollbind, options.cursorbind
    vim.w[win].neon_scroll_sync = nil
  end
end

function M.enroll()
  local state = tabs[vim.api.nvim_get_current_tabpage()]
  if not state then
    return
  end
  for _, win in ipairs(vim.api.nvim_tabpage_list_wins(0)) do
    local new = not state.known[win]
    state.known[win] = true
    if eligible(win) then
      state.wins[win] = state.wins[win] or vim.deepcopy(state.original)
      vim.w[win].neon_scroll_sync = true
      vim.wo[win].scrollbind, vim.wo[win].cursorbind = true, false
    elseif state.wins[win] then
      restore(win, state.wins[win])
      state.wins[win] = nil
    elseif new and not vim.wo[win].diff and vim.api.nvim_win_get_config(win).relative == "" then
      restore(win, state.original)
    end
  end
end

function M.toggle_sync()
  if vim.wo.diff then
    vim.notify("Diff panes already synchronize scrolling and cursor position")
    return
  end
  local tab = vim.api.nvim_get_current_tabpage()
  if tabs[tab] then
    M.enroll()
    for win, options in pairs(tabs[tab].wins) do
      restore(win, options)
    end
    tabs[tab] = nil
    vim.notify("Synchronized scrolling off")
    return
  end
  local state =
    { wins = {}, known = {}, original = { scrollbind = vim.wo.scrollbind, cursorbind = vim.wo.cursorbind } }
  for _, win in ipairs(vim.api.nvim_tabpage_list_wins(tab)) do
    state.known[win] = true
    if eligible(win) then
      state.wins[win] = { scrollbind = vim.wo[win].scrollbind, cursorbind = vim.wo[win].cursorbind }
    end
  end
  if vim.tbl_count(state.wins) < 2 then
    vim.notify("Open two file splits first (Space w v or Space w s)")
    return
  end
  tabs[tab] = state
  M.enroll()
  vim.cmd("syncbind")
  vim.notify("Synchronized scrolling on")
end

function M.setup()
  local group = vim.api.nvim_create_augroup("NeonReading", { clear = true })
  vim.api.nvim_create_autocmd({ "WinEnter", "BufWinEnter", "WinNew" }, {
    group = group,
    callback = function()
      vim.schedule(M.enroll)
    end,
  })
  vim.api.nvim_create_autocmd("TabClosed", {
    group = group,
    callback = function()
      for tab in pairs(tabs) do
        if not vim.api.nvim_tabpage_is_valid(tab) then
          tabs[tab] = nil
        end
      end
    end,
  })
end

return M
