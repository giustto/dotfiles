local M = {}

function M.palette()
  if vim.o.background == "light" then
    return {
      bg = "#f8f9fc", alt = "#eef1f6", surface = "#dfe4ea", border = "#a7b1bf",
      fg = "#1b1f2a", muted = "#6e7681", blue = "#1f6feb", pink = "#bf4ad4",
      green = "#2ea043", red = "#e5484d", yellow = "#d29922", cyan = "#0ea5b7",
      selection = "#cfe3ff", add = "#e0f2e5", delete = "#fbe3e6", change = "#e3edfc", text = "#bdd7fa",
    }
  end
  return {
    bg = "#10131b", alt = "#1a1f2b", surface = "#30384a", border = "#566078",
    fg = "#e6e9ef", muted = "#7a8199", blue = "#57c7ff", pink = "#ff6ac1",
    green = "#5af78e", red = "#ff5c8a", yellow = "#f3f99d", cyan = "#9aedfe",
    selection = "#2a2f45", add = "#18352a", delete = "#3d202e", change = "#1d2b40", text = "#304968",
  }
end

function M.apply()
  vim.cmd("highlight clear")
  vim.g.colors_name = "neon"
  local p = M.palette()
  local groups = {
    Normal = { fg = p.fg, bg = p.bg }, NormalNC = { fg = p.fg, bg = p.bg },
    NormalFloat = { fg = p.fg, bg = p.alt }, FloatBorder = { fg = p.border, bg = p.alt },
    FloatTitle = { fg = p.blue, bold = true }, WinSeparator = { fg = p.border },
    CursorLine = { bg = p.alt }, CursorLineNr = { fg = p.blue, bold = true },
    LineNr = { fg = p.border }, SignColumn = { bg = p.bg },
    Visual = { bg = p.selection }, Search = { fg = p.bg, bg = p.yellow },
    IncSearch = { fg = p.bg, bg = p.pink }, CurSearch = { fg = p.bg, bg = p.pink },
    MatchParen = { fg = p.pink, bold = true, underline = true },
    Comment = { fg = p.muted, italic = true }, NonText = { fg = p.border },
    Whitespace = { fg = p.surface }, EndOfBuffer = { fg = p.bg },
    Directory = { fg = p.blue }, Title = { fg = p.blue, bold = true },
    String = { fg = p.green }, Character = { fg = p.green }, Number = { fg = p.yellow },
    Boolean = { fg = p.yellow }, Constant = { fg = p.yellow },
    Identifier = { fg = p.fg }, Function = { fg = p.blue }, Statement = { fg = p.pink },
    Keyword = { fg = p.pink }, Type = { fg = p.cyan }, Special = { fg = p.cyan },
    PreProc = { fg = p.pink }, Operator = { fg = p.cyan }, Delimiter = { fg = p.fg },
    Error = { fg = p.red }, ErrorMsg = { fg = p.red }, WarningMsg = { fg = p.yellow },
    Todo = { fg = p.bg, bg = p.yellow, bold = true },
    Pmenu = { fg = p.fg, bg = p.alt }, PmenuSel = { bg = p.selection, bold = true },
    PmenuSbar = { bg = p.surface }, PmenuThumb = { bg = p.border },
    StatusLine = { fg = p.fg, bg = p.alt }, StatusLineNC = { fg = p.muted, bg = p.alt },
    TabLine = { fg = p.muted, bg = p.alt }, TabLineFill = { bg = p.alt },
    TabLineSel = { fg = p.blue, bg = p.surface, bold = true },
    WinBar = { fg = p.muted, bg = p.bg }, WinBarNC = { fg = p.muted, bg = p.bg },
    Folded = { fg = p.muted, bg = p.alt }, FoldColumn = { fg = p.border },
    DiffAdd = { bg = p.add }, DiffDelete = { fg = p.red, bg = p.delete },
    DiffChange = { bg = p.change }, DiffText = { bg = p.text, bold = true },
    diffAdded = { fg = p.green }, diffRemoved = { fg = p.red }, diffChanged = { fg = p.blue },
    GitSignsAdd = { fg = p.green }, GitSignsChange = { fg = p.blue }, GitSignsDelete = { fg = p.red },
    DiagnosticError = { fg = p.red }, DiagnosticWarn = { fg = p.yellow },
    DiagnosticInfo = { fg = p.blue }, DiagnosticHint = { fg = p.cyan },
    DiagnosticUnderlineError = { undercurl = true, sp = p.red },
    DiagnosticUnderlineWarn = { undercurl = true, sp = p.yellow },
    SnacksPickerDir = { fg = p.muted }, SnacksPickerDirectory = { fg = p.blue },
    SnacksPickerMatch = { fg = p.pink, bold = true }, SnacksPickerBorder = { fg = p.border },
    SnacksPickerGitStatusUntracked = { fg = p.green }, SnacksPickerGitStatusIgnored = { fg = p.muted },
    WhichKey = { fg = p.blue }, WhichKeyGroup = { fg = p.pink },
    DiffviewFilePanelTitle = { fg = p.blue, bold = true }, DiffviewFilePanelSelected = { fg = p.pink, bold = true },
  }
  for name, spec in pairs(groups) do
    vim.api.nvim_set_hl(0, name, spec)
  end
  local links = {
    ["@variable"] = "Identifier", ["@variable.builtin"] = "Special", ["@property"] = "Identifier",
    ["@function"] = "Function", ["@function.builtin"] = "Special", ["@keyword"] = "Keyword",
    ["@string"] = "String", ["@type"] = "Type", ["@comment"] = "Comment",
    ["@markup.heading"] = "Title", ["@markup.link"] = "Underlined",
    SnacksPickerGitStatusAdded = "GitSignsAdd", SnacksPickerGitStatusModified = "GitSignsChange",
    SnacksPickerGitStatusDeleted = "GitSignsDelete", DiffviewDiffAddAsDelete = "DiffDelete",
    DiffviewDiffDelete = "DiffDelete", BlinkCmpMenu = "Pmenu", BlinkCmpMenuSelection = "PmenuSel",
  }
  for name, target in pairs(links) do
    vim.api.nvim_set_hl(0, name, { link = target })
  end
  for i, color in ipairs({ p.surface, p.red, p.green, p.yellow, p.blue, p.pink, p.cyan, p.fg,
    p.border, p.red, p.green, p.yellow, p.blue, p.pink, p.cyan, p.fg }) do
    vim.g["terminal_color_" .. (i - 1)] = color
  end
end

function M.sync()
  if vim.fn.has("mac") == 0 then return end
  vim.system({ "defaults", "read", "-g", "AppleInterfaceStyle" }, { text = true }, function(result)
    vim.schedule(function()
      local mode = result.code == 0 and result.stdout:lower():find("dark") and "dark" or "light"
      if vim.o.background ~= mode then
        vim.o.background = mode
        vim.cmd.colorscheme("neon")
      end
    end)
  end)
end

function M.setup()
  vim.cmd.colorscheme("neon")
  M.sync()
  vim.api.nvim_create_autocmd("FocusGained", {
    group = vim.api.nvim_create_augroup("NeonAppearance", { clear = true }), callback = M.sync,
  })
end

return M
