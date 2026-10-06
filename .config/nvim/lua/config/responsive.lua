local M = {}

local function size()
  return vim.o.columns, vim.o.lines
end

function M.compact()
  local columns, lines = size()
  return columns < 80 or lines < 20
end

function M.picker_layout()
  local columns, lines = size()
  if columns >= 140 and lines >= 28 then return "default" end
  return M.compact() and "compact" or "vertical"
end

function M.explorer_floating()
  local columns, lines = size()
  return columns < 85 or lines < 16
end

function M.explorer_layout()
  if M.explorer_floating() then return { preset = "compact", preview = false } end
  local columns = vim.o.columns
  return {
    preset = "sidebar",
    preview = false,
    layout = { width = math.min(30, math.max(20, math.floor(columns * 0.23))), min_width = 20 },
  }
end

function M.review_layout()
  local columns, lines = size()
  if columns >= 140 or (lines < 24 and columns >= 125) then return "diff2_horizontal" end
  return "diff2_vertical"
end

local configured = setmetatable({}, { __mode = "k" })
local auto_hidden = setmetatable({}, { __mode = "k" })

local function configure_panel(view)
  if configured[view] or not view.panel then return end
  local panel = view.panel
  local base = panel:get_config()
  if view.files then
    panel.config_producer = function()
      local config = vim.deepcopy(base)
      config.width = math.min(28, math.max(18, math.floor(vim.o.columns * 0.2)))
      return config
    end
  else
    panel.config_producer = function()
      local config = vim.deepcopy(base)
      config.height = math.min(10, math.max(5, math.floor(vim.o.lines * 0.3)))
      return config
    end
  end
  configured[view] = true
end

local function resize_review(view)
  if not view or not view.panel then return end
  configure_panel(view)

  local panel = view.panel
  if view.files and vim.o.columns < 100 then
    if panel:is_open() then
      auto_hidden[view] = true
      panel:close()
    end
  elseif auto_hidden[view] then
    local current_win = vim.api.nvim_get_current_win()
    panel:open()
    if vim.api.nvim_win_is_valid(current_win) then vim.api.nvim_set_current_win(current_win) end
    auto_hidden[view] = nil
  end
  panel:resize()

  local target_name = M.review_layout()
  if view._neon_layout == target_name then return end
  local horizontal = require("diffview.scene.layouts.diff_2_hor").Diff2Hor
  local vertical = require("diffview.scene.layouts.diff_2_ver").Diff2Ver
  local target = target_name == "diff2_horizontal" and horizontal or vertical
  local entries = {}
  if view.files then
    for _, entry in view.files:iter() do entries[#entries + 1] = entry end
  elseif panel.list_files then
    entries = panel:list_files()
  end
  local changed = false
  for _, entry in ipairs(entries) do
    local class = entry.layout.class
    if (class == horizontal or class == vertical) and class ~= target then
      entry:convert_layout(target)
      changed = true
    end
  end
  view._neon_layout = target_name
  if changed then
    local entry = view.cur_entry or (view.cur_file and view:cur_file())
    if entry then view:set_file(entry, not panel:is_focused()) end
  end
end

function M.apply()
  local lib = package.loaded["diffview.lib"]
  if lib then
    local config = require("diffview.config").get_config()
    config.view.default.layout = M.review_layout()
    config.view.file_history.layout = M.review_layout()
    resize_review(lib.get_current_view())
  end
  if _G.Snacks then
    for _, picker in ipairs(Snacks.picker.get({ source = "explorer" })) do
      local floating = M.explorer_floating()
      picker.opts.auto_close = false
      if picker:on_current_tab() then picker:set_layout() end
      picker.opts.auto_close = floating
      picker.opts.jump.close = floating
    end
  end
end

function M.setup()
  local group = vim.api.nvim_create_augroup("NeonResponsive", { clear = true })
  vim.api.nvim_create_autocmd({ "VimResized", "TabEnter" }, {
    group = group, callback = function() vim.schedule(M.apply) end,
  })
  vim.api.nvim_create_autocmd("User", {
    group = group,
    pattern = { "DiffviewViewOpened", "DiffviewViewEnter" },
    callback = function() vim.schedule(M.apply) end,
  })
end

return M
