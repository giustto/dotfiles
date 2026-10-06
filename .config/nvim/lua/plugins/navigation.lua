return {
  {
    "nvim-mini/mini.icons",
    config = function()
      require("mini.icons").setup()
      require("mini.icons").mock_nvim_web_devicons()
    end,
  },
  {
    "folke/snacks.nvim",
    priority = 1000,
    opts = {
      bigfile = { enabled = true },
      explorer = { enabled = true },
      input = { enabled = true },
      notifier = { enabled = true, timeout = 3000 },
      quickfile = { enabled = true },
      statuscolumn = { enabled = true },
      lazygit = { win = { position = "float", width = 0.95, height = 0.95, border = "rounded" } },
      terminal = { win = { position = "bottom", height = 0.35, border = "top" } },
      picker = {
        enabled = true,
        layout = {
          preset = function() return require("config.responsive").picker_layout() end,
        },
        layouts = {
          vertical = { layout = { width = 0.9, min_width = 30, height = 0.9, min_height = 12 } },
          compact = {
            preview = false,
            layout = {
              backdrop = false, width = 0.95, min_width = 1, height = 0.9, min_height = 4,
              box = "vertical", border = true, title = "{title} {live} {flags}",
              { win = "input", height = 1, border = "bottom" },
              { win = "list", border = "none" },
            },
          },
        },
        sources = {
          explorer = {
            diagnostics = false,
            hidden = true,
            ignored = true,
            exclude = { ".git" },
            follow_file = true,
            auto_close = false,
            layout = function() return require("config.responsive").explorer_layout() end,
            config = function(opts)
              local floating = require("config.responsive").explorer_floating()
              opts.auto_close = floating
              opts.jump.close = floating
              return require("snacks.picker.source.explorer").setup(opts)
            end,
            win = { list = { keys = {
              ["<C-h>"] = false, ["<C-j>"] = false, ["<C-k>"] = false, ["<C-l>"] = false,
            } } },
          },
          files = { hidden = true, exclude = { ".git" } },
          grep = { hidden = true, exclude = { ".git" } },
        },
      },
    },
  },
  {
    "folke/which-key.nvim",
    event = "VeryLazy",
    opts = {
      delay = 300,
      preset = "classic",
      spec = {
        { "<leader>b", group = "buffers" },
        { "<leader>f", group = "find" },
        { "<leader>g", group = "git / hunks" },
        { "<leader>r", group = "review" },
        { "<leader>s", group = "search" },
        { "<leader>t", group = "tabs / terminal" },
        { "<leader>u", group = "interface" },
        { "<leader>w", group = "windows" },
      },
    },
  },
  {
    "nvim-lualine/lualine.nvim",
    dependencies = { "nvim-mini/mini.icons" },
    opts = function()
      return {
        options = {
          theme = function()
            local p = require("config.theme").palette()
            local function mode(color)
              return { a = { fg = p.bg, bg = color, gui = "bold" },
                b = { fg = p.fg, bg = p.surface }, c = { fg = p.muted, bg = p.alt } }
            end
            return { normal = mode(p.blue), insert = mode(p.green), visual = mode(p.pink),
              replace = mode(p.red), command = mode(p.yellow), inactive = mode(p.border) }
          end,
          globalstatus = true,
          component_separators = "", section_separators = "",
        },
        sections = {
          lualine_a = { { "mode", fmt = function(s) return s:sub(1, 1) end } },
          lualine_b = {
            { "branch", cond = function() return vim.o.columns >= 70 end },
            { "diff", cond = function() return vim.o.columns >= 100 end },
          },
          lualine_c = { { "filename", path = 0 } },
          lualine_x = { { "filetype", cond = function() return vim.o.columns >= 95 end } },
          lualine_y = { { "progress", cond = function() return vim.o.columns >= 70 end } },
          lualine_z = { "location" },
        },
        extensions = { "lazy", "quickfix" },
      }
    end,
  },
}
