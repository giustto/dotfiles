-- Run with the config loaded: nvim --headless '+luafile ~/.config/nvim/tests/review.lua'
-- Uses only temporary repositories; never stages or commits the user's files.
local function test()
  vim.o.columns, vim.o.lines = 115, 35
  assert(require("config.tabline").render():find("Workspace", 1, true), "Unnamed editor tab is a workspace")
  require("lazy").load({ plugins = { "diffview.nvim", "gitsigns.nvim", "grug-far.nvim", "which-key.nvim", "mini.ai" } })
  local errors = {}
  local notify = vim.notify
  vim.notify = function(message, level, opts)
    if level == vim.log.levels.ERROR then errors[#errors + 1] = tostring(message) end
    notify(message, level, opts)
  end
  local root = vim.fn.tempname() .. " review repo"
  vim.fn.mkdir(root, "p")
  local function git(...)
    local args = { "git", "-C", root }
    vim.list_extend(args, { ... })
    local result = vim.system(args, { text = true }):wait()
    assert(result.code == 0, result.stderr)
    return vim.trim(result.stdout)
  end
  local function write(path, lines) vim.fn.writefile(lines, root .. "/" .. path) end
  git("init", "-b", "main")
  git("config", "user.name", "Neon Test")
  git("config", "user.email", "neon@example.invalid")
  write("tracked file.txt", { "base" })
  write("other.txt", { "other" })
  write(".env.example", { "VISIBLE=true" })
  write(".gitignore", { "ignored.txt", ".cache/" })
  git("add", ".")
  git("commit", "-m", "Initial fixture")
  git("switch", "-c", "agent/work")
  write("tracked file.txt", { "agent commit" })
  git("commit", "-am", "Agent changes tracked file")
  local head = git("rev-parse", "HEAD")
  vim.cmd.cd(root)
  vim.cmd.edit(vim.fn.fnameescape(root .. "/tracked file.txt"))
  local review = require("config.review")
  assert(review.root() == vim.uv.fs_realpath(root), "Git root with spaces")
  review.checkpoint()
  write("tracked file.txt", { "agent commit", "staged" })
  git("add", "tracked file.txt")
  write("tracked file.txt", { "agent commit", "staged", "unstaged" })
  write("new file.txt", { "untracked" })
  write("ignored.txt", { "hidden by gitignore" })
  vim.fn.mkdir(root .. "/.cache", "p")
  write(".cache/state.txt", { "ignored hidden folder" })
  local lib = require("diffview.lib")
  local function wait_for(predicate, message, timeout)
    assert(vim.wait(timeout or 5000, predicate, 20), message)
  end
  local function current_diff()
    wait_for(function() return lib.get_current_view() ~= nil end, "Review tab opens")
    local view = lib.get_current_view()
    assert(view, "Review tab exists")
    wait_for(function() return view.files:len() > 0 end, "Diff contains files")
    vim.wait(500)
    return view
  end
  local function close()
    require("diffview").close()
    vim.wait(100)
  end
  review.open()
  local view = current_diff()
  local tabline = require("config.tabline").render()
  assert(tabline:find("Review", 1, true), "Review tab has a clear label")
  assert(tabline:find("tracked file.txt", 1, true), "Editor tab shows its file")
  assert(not tabline:find(root, 1, true), "Tab labels omit full paths")
  assert(#view.files.staged == 1, "Staged section")
  assert(#view.files.working == 2, "Unstaged and untracked sections")
  assert(review.root() == vim.uv.fs_realpath(root), "Repository in review panel")
  local responsive = require("config.responsive")
  local horizontal = require("diffview.scene.layouts.diff_2_hor").Diff2Hor
  local vertical = require("diffview.scene.layouts.diff_2_ver").Diff2Ver
  vim.o.columns, vim.o.lines = 160, 40
  responsive.apply()
  assert(view.cur_entry.layout.class == horizontal, "Wide review uses side-by-side diffs")
  assert(view.panel:is_open(), "Wide review keeps file list visible")
  vim.o.columns, vim.o.lines = 95, 30
  responsive.apply()
  assert(view.cur_entry.layout.class == vertical, "Narrow review stacks diffs")
  assert(not view.panel:is_open(), "Narrow review gives width to the diff")
  vim.o.columns, vim.o.lines = 70, 18
  responsive.apply()
  assert(responsive.picker_layout() == "compact", "Small picker hides preview")
  assert(responsive.explorer_layout().preset == "compact", "Small explorer floats over editor")
  local picker_config = require("snacks.picker.config")
  local narrow_explorer = picker_config.get({ source = "explorer" })
  assert(narrow_explorer.auto_close and narrow_explorer.jump.close, "Small explorer closes after file selection")
  assert(vim.tbl_contains(picker_config.layout(narrow_explorer).hidden, "preview"), "Small explorer omits preview")
  vim.o.columns, vim.o.lines = 40, 12
  responsive.apply()
  assert(view.cur_entry.layout.class == vertical and not view.panel:is_open(), "Very small review keeps one full-width diff")
  vim.o.columns, vim.o.lines = 115, 35
  responsive.apply()
  assert(view.panel:is_open(), "File list returns when terminal widens")
  local wide_explorer = picker_config.get({ source = "explorer" })
  assert(not wide_explorer.auto_close and not wide_explorer.jump.close, "Wide explorer stays open")
  write("auto refresh.txt", { "written while review is open" })
  wait_for(function() return #view.files.working == 3 end, "Open review refreshes after external file change", 8000)
  assert(vim.fn.delete(root .. "/auto refresh.txt") == 0, "Remove temporary refresh fixture")
  wait_for(function() return #view.files.working == 2 end, "Open review removes deleted file", 8000)
  close()
  vim.o.columns, vim.o.lines = 70, 18
  review.open(nil, nil, { "--cached" })
  view = current_diff()
  assert(view.files:len() == 1, "Staged-only review excludes untracked files")
  assert(view.cur_entry.layout.class == vertical, "Review opened narrow uses stacked diff")
  close()
  vim.o.columns, vim.o.lines = 115, 35
  review.open("main...HEAD")
  assert(current_diff().files:len() == 1, "Branch review excludes dirty working tree")
  assert(git("branch", "--show-current") == "agent/work", "Review keeps current branch")
  close()
  review.open(head .. "^!")
  assert(current_diff().files:len() == 1, "Single commit review")
  close()
  review.since_checkpoint()
  assert(current_diff().left.commit == head, "Checkpoint keeps original HEAD")
  close()
  vim.cmd.edit(vim.fn.fnameescape(root .. "/tracked file.txt"))
  review.history(true)
  view = lib.get_current_view()
  assert(view, "File history opens")
  wait_for(function() return #view.panel.entries > 0 end, "File history populated")
  vim.wait(500)
  assert(#view.adapter.ctx.path_args == 1, "History restricted to current file")
  vim.o.columns, vim.o.lines = 85, 16
  responsive.apply()
  assert(view.panel:get_config().height == 5, "Short history panel leaves room for diff")
  vim.o.columns, vim.o.lines = 115, 35
  responsive.apply()
  close()
  local status_before = git("status", "--porcelain")
  local branch_picker = review.branches()
  wait_for(function() return branch_picker.shown and not branch_picker:is_active() end, "Branch picker ready")
  local base
  for _, item in ipairs(branch_picker:items()) do
    if item.branch == "main" then base = item end
  end
  assert(base, "Base branch offered")
  branch_picker.opts.confirm(branch_picker, base)
  assert(current_diff().rev_arg == "main...HEAD", "Branch Enter opens merge-base review")
  close()
  local commit_picker = review.commits()
  wait_for(function() return commit_picker.shown and not commit_picker:is_active() end, "Commit picker ready")
  local commit = commit_picker:items()[1]
  commit_picker.opts.confirm(commit_picker, commit)
  assert(current_diff().rev_arg == commit.commit .. "^!", "Commit Enter opens patch")
  close()
  assert(git("status", "--porcelain") == status_before, "Review leaves index and working tree intact")
  assert(git("branch", "--show-current") == "agent/work", "Pickers never check out another ref")
  local worktree = root .. "-worktree"
  git("worktree", "add", worktree, "main")
  vim.cmd.edit(vim.fn.fnameescape(worktree .. "/tracked file.txt"))
  assert(review.root() == vim.uv.fs_realpath(worktree), "Linked worktree uses its own root")
  vim.cmd.edit(vim.fn.fnameescape(root .. "/tracked file.txt"))
  local picker = Snacks.explorer({ cwd = root })
  wait_for(function() return #picker:items() > 0 end, "Explorer populated")
  assert(picker.resolved_layout.preset == "sidebar", "Wide explorer starts as sidebar")
  vim.o.columns, vim.o.lines = 70, 18
  vim.api.nvim_exec_autocmds("VimResized", {})
  assert(vim.wait(5000, function() return picker.resolved_layout.preset == "compact" end, 20),
    "Open explorer adapts to narrow terminal: " .. tostring(picker.resolved_layout.preset)
      .. " closed=" .. tostring(picker.closed) .. " at " .. vim.o.columns .. "x" .. vim.o.lines)
  assert(picker.opts.auto_close and picker.opts.jump.close, "Open narrow explorer becomes temporary")
  vim.o.columns, vim.o.lines = 115, 35
  vim.api.nvim_exec_autocmds("VimResized", {})
  wait_for(function() return picker.resolved_layout.preset == "sidebar" end, "Open explorer returns to sidebar")
  assert(not picker.opts.auto_close, "Wide explorer remains persistent")
  vim.wait(1000)
  local files = {}
  for _, item in ipairs(picker:items()) do files[vim.fs.basename(item.file or "")] = true end
  assert(files[".env.example"], "Dotfiles visible")
  assert(files[".cache"], "Ignored hidden folders visible")
  assert(files["ignored.txt"], "Ignored files visible")
  assert(not files[".git"], "Git internals excluded")
  picker:close()
  vim.wait(100)
  vim.o.columns, vim.o.lines = 40, 12
  local small_picker = Snacks.picker.files({ cwd = root })
  wait_for(function() return small_picker.shown and #small_picker:items() > 0 end, "Small file picker opens")
  assert(vim.tbl_contains(small_picker.resolved_layout.hidden, "preview"), "Small file picker uses compact layout")
  vim.wait(100)
  small_picker:close()
  local small_explorer = Snacks.explorer({ cwd = root })
  wait_for(function() return small_explorer.shown and #small_explorer:items() > 0 end, "Small explorer opens")
  assert(small_explorer.resolved_layout.preset == "compact", "Small explorer uses compact layout")
  vim.wait(100)
  small_explorer:close()
  vim.wait(100)
  vim.o.columns, vim.o.lines = 115, 35
  for _, mode in ipairs({ "dark", "light" }) do
    vim.o.background = mode
    vim.cmd.colorscheme("neon")
    assert(vim.g.colors_name == "neon", "Theme loads")
    local normal = vim.api.nvim_get_hl(0, { name = "Normal" })
    assert(normal.bg == tonumber(mode == "dark" and "10131b" or "f8f9fc", 16), "Ghostty background matches")
  end
  vim.wait(300)
  assert(#errors == 0, table.concat(errors, "\n"))
  assert(vim.v.errmsg == "", vim.v.errmsg)
  print("PASS: startup, live review refresh, responsive reviews/pickers/explorer, staged/unstaged/untracked diffs, branch/commit pickers, checkpoint, file history, worktrees, neon light/dark")
end

local ok, err = xpcall(test, debug.traceback)
if not ok then
  io.stderr:write(err .. "\n")
  vim.cmd("cquit 1")
else
  vim.cmd("qa!")
end
