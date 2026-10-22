local M = {}

-- Colors are generated from .config/theme/palette.json.
function M.palette()
  return require("config.palette")[vim.o.background]
end

function M.apply()
  vim.cmd("highlight clear")
  vim.g.colors_name = "neon"
  local p = M.palette()
  local neon = p.neon or p
  local on_neon = p.neon and p.fg or p.bg
  local groups = {
    Normal = { fg = p.fg, bg = p.bg },
    NormalNC = { fg = p.fg, bg = p.bg },
    NormalFloat = { fg = p.fg, bg = p.alt },
    FloatBorder = { fg = p.border, bg = p.alt },
    FloatTitle = { fg = p.blue, bold = true },
    WinSeparator = { fg = p.border },
    NeonActiveBorder = { fg = p.blue },
    CursorLine = { bg = p.alt },
    CursorLineNr = { fg = p.blue, bold = true },
    LineNr = { fg = p.border },
    SignColumn = { bg = p.bg },
    Visual = { bg = p.selection },
    Search = { fg = on_neon, bg = neon.yellow },
    IncSearch = { fg = on_neon, bg = neon.pink },
    CurSearch = { fg = on_neon, bg = neon.pink },
    MatchParen = { fg = p.pink, bold = true, underline = true },
    Comment = { fg = p.muted, italic = true },
    NonText = { fg = p.border },
    Whitespace = { fg = p.surface },
    EndOfBuffer = { fg = p.bg },
    Directory = { fg = p.blue },
    Title = { fg = p.blue, bold = true },
    String = { fg = p.green },
    Character = { fg = p.green },
    Number = { fg = p.yellow },
    Boolean = { fg = p.yellow },
    Constant = { fg = p.yellow },
    Identifier = { fg = p.fg },
    Function = { fg = p.blue },
    Statement = { fg = p.pink },
    Keyword = { fg = p.pink },
    Type = { fg = p.cyan },
    Special = { fg = p.cyan },
    PreProc = { fg = p.pink },
    Operator = { fg = p.cyan },
    Delimiter = { fg = p.fg },
    Error = { fg = p.red },
    ErrorMsg = { fg = p.red },
    WarningMsg = { fg = p.yellow },
    Todo = { fg = on_neon, bg = neon.yellow, bold = true },
    Underlined = { fg = p.blue, underline = true },
    Conceal = { fg = p.muted },
    SpecialKey = { fg = p.muted },
    Pmenu = { fg = p.fg, bg = p.alt },
    PmenuSel = { fg = p.fg, bg = p.neon and neon.cyan or p.selection, bold = true },
    PmenuSbar = { bg = p.surface },
    PmenuThumb = { bg = p.border },
    StatusLine = { fg = p.fg, bg = p.alt },
    StatusLineNC = { fg = p.muted, bg = p.alt },
    TabLine = { fg = p.muted, bg = p.alt },
    TabLineFill = { bg = p.alt },
    TabLineSel = { fg = p.neon and p.fg or p.blue, bg = p.neon and neon.cyan or p.surface, bold = true },
    WinBar = { fg = p.muted, bg = p.bg },
    WinBarNC = { fg = p.muted, bg = p.bg },
    Folded = { fg = p.muted, bg = p.alt },
    FoldColumn = { fg = p.border },
    DiffAdd = { bg = p.add },
    DiffDelete = { fg = p.red, bg = p.delete },
    DiffChange = { bg = p.change },
    DiffText = { bg = p.text, bold = true },
    diffAdded = { fg = p.green },
    diffRemoved = { fg = p.red },
    diffChanged = { fg = p.blue },
    GitSignsAdd = { fg = p.green },
    GitSignsChange = { fg = p.blue },
    GitSignsDelete = { fg = p.red },
    DiagnosticError = { fg = p.red },
    DiagnosticWarn = { fg = p.yellow },
    DiagnosticInfo = { fg = p.blue },
    DiagnosticHint = { fg = p.cyan },
    DiagnosticUnderlineError = { undercurl = true, sp = p.red },
    DiagnosticUnderlineWarn = { undercurl = true, sp = p.yellow },
    DiagnosticUnderlineInfo = { undercurl = true, sp = p.blue },
    DiagnosticUnderlineHint = { undercurl = true, sp = p.cyan },
    SpellBad = { undercurl = true, sp = p.red },
    SpellCap = { undercurl = true, sp = p.yellow },
    SpellLocal = { undercurl = true, sp = p.cyan },
    SpellRare = { undercurl = true, sp = p.pink },
    SnacksIndent = { fg = p.surface },
    SnacksIndentScope = { fg = p.border },
    SnacksPickerDir = { fg = p.muted },
    SnacksPickerDirectory = { fg = p.blue },
    SnacksPickerMatch = { fg = p.pink, bold = true },
    SnacksPickerBorder = { fg = p.border },
    SnacksPickerGitStatusUntracked = { fg = p.green },
    SnacksPickerGitStatusIgnored = { fg = p.muted },
    WhichKey = { fg = p.blue },
    WhichKeyGroup = { fg = p.pink },
    DiffviewFilePanelTitle = { fg = p.blue, bold = true },
    DiffviewFilePanelSelected = { fg = p.pink, bold = true },
  }
  for name, spec in pairs(groups) do
    vim.api.nvim_set_hl(0, name, spec)
  end
  local links = {
    ["@variable"] = "Identifier",
    ["@variable.builtin"] = "Special",
    ["@property"] = "Identifier",
    ["@function"] = "Function",
    ["@function.builtin"] = "Special",
    ["@keyword"] = "Keyword",
    ["@string"] = "String",
    ["@type"] = "Type",
    ["@comment"] = "Comment",
    ["@markup.heading"] = "Title",
    ["@markup.link"] = "Underlined",
    SnacksPickerGitStatusAdded = "GitSignsAdd",
    SnacksPickerGitStatusModified = "GitSignsChange",
    SnacksPickerGitStatusDeleted = "GitSignsDelete",
    DiffviewDiffAddAsDelete = "DiffDelete",
    DiffviewDiffDelete = "DiffDelete",
    DiffviewDiffAdd = "DiffAdd",
    DiffviewDiffChange = "DiffChange",
    DiffviewDiffText = "DiffText",
    DiffviewDiffDeleteDim = "NonText",
    BlinkCmpMenu = "Pmenu",
    BlinkCmpMenuSelection = "PmenuSel",
  }
  for name, target in pairs(links) do
    vim.api.nvim_set_hl(0, name, { link = target })
  end
  for i, color in ipairs(require("config.palette").ansi[vim.o.background]) do
    vim.g["terminal_color_" .. (i - 1)] = color
  end
end

function M.sync()
  if vim.g.neon_appearance == "manual" then
    return
  end
  if vim.fn.has("mac") == 0 then
    return
  end
  vim.system({ "defaults", "read", "-g", "AppleInterfaceStyle" }, { text = true }, function(result)
    vim.schedule(function()
      if vim.g.neon_appearance == "manual" then
        return
      end
      local mode = result.code == 0 and result.stdout:lower():find("dark") and "dark" or "light"
      if vim.o.background ~= mode then
        vim.o.background = mode
        vim.cmd.colorscheme("neon")
      end
    end)
  end)
end

function M.focus()
  local current = vim.api.nvim_get_current_win()
  for _, win in ipairs(vim.api.nvim_tabpage_list_wins(0)) do
    if vim.api.nvim_win_get_config(win).relative == "" then
      vim.api.nvim_win_call(win, function()
        vim.opt_local.winhighlight:append({
          WinSeparator = win == current and "NeonActiveBorder" or "WinSeparator",
        })
      end)
    end
  end
end

function M.setup()
  vim.cmd.colorscheme("neon")
  M.sync()
  vim.api.nvim_create_user_command("ThemeReload", function()
    package.loaded["config.palette"] = nil
    vim.cmd.colorscheme("neon")
    vim.cmd("redrawstatus")
    vim.notify("Generated palette reloaded")
  end, { desc = "Reload colors exported by scripts/theme" })
  vim.api.nvim_create_autocmd("FocusGained", {
    group = vim.api.nvim_create_augroup("NeonAppearance", { clear = true }),
    callback = M.sync,
  })
  vim.api.nvim_create_autocmd({ "WinEnter", "WinNew", "ColorScheme" }, {
    group = "NeonAppearance",
    callback = function()
      vim.schedule(M.focus)
    end,
  })
end

return M
