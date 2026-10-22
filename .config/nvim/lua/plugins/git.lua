return {
  {
    "sindrets/diffview.nvim",
    cmd = { "DiffviewOpen", "DiffviewClose", "DiffviewFileHistory", "DiffviewRefresh" },
    dependencies = { "nvim-lua/plenary.nvim", "nvim-mini/mini.icons" },
    opts = function()
      local actions = require("diffview.actions")
      local layout = require("config.responsive").review_layout()
      local shared = {
        { "n", "q", "<Cmd>DiffviewClose<CR>", { desc = "Close review" } },
        { "n", "<leader>e", actions.focus_files, { desc = "Focus review files" } },
        { "n", "<leader>b", false },
        { "n", "<leader>rf", actions.toggle_files, { desc = "Toggle review files" } },
        { "n", "<leader>rl", actions.cycle_layout, { desc = "Cycle diff layout" } },
      }
      return {
        enhanced_diff_hl = true,
        hooks = { diff_buf_win_enter = require("config.reading").diff_window },
        view = {
          default = { layout = layout, winbar_info = true, disable_diagnostics = true },
          file_history = { layout = layout, winbar_info = true, disable_diagnostics = true },
          merge_tool = { layout = "diff3_mixed", winbar_info = true, disable_diagnostics = true },
        },
        file_panel = { win_config = { width = 28 }, tree_options = { flatten_dirs = false } },
        file_history_panel = { win_config = { position = "bottom", height = 10 } },
        keymaps = {
          view = shared,
          file_panel = vim.list_extend(vim.deepcopy(shared), {
            { "n", "<CR>", actions.focus_entry, { desc = "Open file and focus diff" } },
            { "n", "l", actions.focus_entry, { desc = "Open file and focus diff" } },
          }),
          file_history_panel = vim.list_extend(vim.deepcopy(shared), {
            { "n", "<CR>", actions.focus_entry, { desc = "Open file and focus diff" } },
          }),
        },
      }
    end,
  },
  {
    "lewis6991/gitsigns.nvim",
    event = { "BufReadPre", "BufNewFile" },
    opts = {
      signs = { add = { text = "▎" }, change = { text = "▎" }, delete = { text = "▁" }, topdelete = { text = "▔" }, changedelete = { text = "▎" } },
      current_line_blame = false,
      attach_to_untracked = true,
      on_attach = function(buf)
        local gs = require("gitsigns")
        local function map(mode, lhs, rhs, desc)
          vim.keymap.set(mode, lhs, rhs, { buffer = buf, desc = desc })
        end
        for key, direction in pairs({ ["]h"] = "next", ["[h"] = "prev" }) do
          map("n", key, function()
            if vim.wo.diff then
              vim.cmd.normal({ direction == "next" and "]c" or "[c", bang = true })
            else
              gs.nav_hunk(direction)
            end
          end, direction .. " change")
        end
        map("n", "<leader>gp", gs.preview_hunk, "Preview hunk")
        map("n", "<leader>gs", gs.stage_hunk, "Stage / unstage hunk")
        map("x", "<leader>gs", function() gs.stage_hunk({ vim.fn.line("."), vim.fn.line("v") }) end, "Stage selected lines")
        map("n", "<leader>gR", function()
          vim.ui.select({ "Cancel", "Discard hunk" }, { prompt = "Discard this hunk?" }, function(choice)
            if choice == "Discard hunk" then gs.reset_hunk() end
          end)
        end, "Discard hunk (confirm)")
        map("n", "<leader>gb", function() gs.blame_line({ full = true }) end, "Blame line / commit message")
        map("n", "<leader>gB", gs.blame, "Blame file")
        map("n", "<leader>ub", gs.toggle_current_line_blame, "Toggle inline blame")
        map({ "o", "x" }, "ih", gs.select_hunk, "Select hunk")
      end,
    },
  },
}
