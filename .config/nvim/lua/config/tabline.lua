local M = {}

local function label(tab)
  local lib = package.loaded["diffview.lib"]
  local view = lib and lib.tabpage_to_view(tab)
  if view then return view.panel and view.panel.entries and "History" or "Review" end

  local current_win = vim.api.nvim_tabpage_get_win(tab)
  local wins = { current_win }
  for _, win in ipairs(vim.api.nvim_tabpage_list_wins(tab)) do
    if win ~= current_win then wins[#wins + 1] = win end
  end
  for _, win in ipairs(wins) do
    local buf = vim.api.nvim_win_get_buf(win)
    local name = vim.api.nvim_buf_get_name(buf)
    if vim.bo[buf].buftype == "" and name ~= "" then
      return vim.fn.fnamemodify(name, ":t")
    end
  end
  return "Workspace"
end

function M.render()
  local current = vim.api.nvim_get_current_tabpage()
  local parts = {}
  local tabs = vim.api.nvim_list_tabpages()
  local max_name = math.max(4, math.floor(vim.o.columns / #tabs) - 2)
  for number, tab in ipairs(tabs) do
    local group = tab == current and "TabLineSel" or "TabLine"
    local name = label(tab)
    if vim.fn.strdisplaywidth(name) > max_name then
      name = vim.fn.strcharpart(name, 0, max_name - 1) .. "…"
    end
    name = name:gsub("%%", "%%%%")
    parts[#parts + 1] = string.format("%%%dT%%#%s# %s ", number, group, name)
  end
  parts[#parts + 1] = "%T%#TabLineFill#"
  return table.concat(parts)
end

return M
