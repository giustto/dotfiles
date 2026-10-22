local function test()
  vim.o.columns, vim.o.lines = 130, 38
  local api, uv = vim.api, vim.uv
  local root = vim.fn.tempname() .. "-refresh"
  vim.fn.mkdir(root, "p")
  root = uv.fs_realpath(root)
  local project = require("config.project")
  local function git(...)
    local value, err = project.git(root, { ... })
    assert(value, err)
    return value
  end
  local function write(path, text)
    vim.fn.writefile({ text }, root .. "/" .. path)
  end
  local function wait(predicate, message, timeout)
    assert(vim.wait(timeout or 2500, predicate, 20), message)
  end
  git("init", "-b", "main")
  git("config", "user.name", "Refresh test")
  git("config", "user.email", "test@example.invalid")
  write("one.txt", "base")
  write("two.txt", "second")
  git("add", ".")
  git("commit", "-m", "base")
  write("one.txt", "committed")
  git("commit", "-am", "second")
  vim.cmd.cd(root)
  vim.cmd.edit(root .. "/one.txt")
  local buffer = api.nvim_get_current_buf()
  -- No wait between initial read and disk edit: exercise watcher installation races.
  write("one.txt", "changed immediately after initial read")
  wait(function()
    return api.nvim_buf_get_lines(buffer, 0, 1, false)[1] == "changed immediately after initial read"
  end, "Initial external edit detected")
  assert(vim.fn.delete(root .. "/one.txt") == 0)
  wait(function()
    return vim.b[buffer].neon_external_change
  end, "Deletion surfaced without destroying text")
  assert(
    api.nvim_buf_get_lines(buffer, 0, 1, false)[1] == "changed immediately after initial read",
    "Deleted buffer text retained"
  )
  write("one.txt", "recreated externally")
  wait(function()
    return api.nvim_buf_get_lines(buffer, 0, 1, false)[1] == "recreated externally"
  end, "Recreated file reloads")
  local review = require("config.review")
  review.open()
  local lib = require("diffview.lib")
  local view = lib.get_current_view()
  wait(function()
    return view.ready and view.cur_entry
  end, "Review ready", 5000)
  vim.wait(400)
  vim.fn.mkdir(root .. "/nested/deep", "p")
  write("nested/deep/new.txt", "new nested file")
  wait(function()
    return #view.files.working == 2
  end, "Nested new files appear live")
  local tab = view.tabpage
  vim.cmd.tabprevious()
  write("background.txt", "background change")
  vim.wait(250)
  api.nvim_set_current_tabpage(tab)
  wait(function()
    return #view.files.working == 3
  end, "Hidden review catches up on entry")
  git("add", "one.txt")
  wait(function()
    return #view.files.staged == 1
  end, "External staging updates review")
  local staged = view.files.staged[1]
  view:set_file(staged, true)
  vim.wait(400)
  write("one.txt", "second index version")
  git("add", "one.txt")
  wait(function()
    local file = staged.layout.b.file
    return file:is_valid() and api.nvim_buf_get_lines(file.bufnr, 0, 1, false)[1] == "second index version"
  end, "Repeated index updates reload staged content")
  vim.wait(400)
  require("diffview").close()
  vim.wait(200)
  git("add", ".")
  git("commit", "-m", "working changes")
  vim.cmd.edit(root .. "/one.txt")
  review.history(false)
  view = lib.get_current_view()
  wait(function()
    return view.ready and #view.panel.entries >= 3 and not view.panel.updating
  end, "History ready", 5000)
  vim.wait(500)
  local selected = view.panel.cur_item[1].commit.hash
  local selected_path = view.panel.cur_item[2].path
  local count = #view.panel.entries
  write("two.txt", "new external commit")
  git("commit", "-am", "new history entry")
  wait(function()
    return #view.panel.entries == count + 1 and not view.panel.updating and not view.neon_refreshing
  end, "History list refreshes without reopening")
  vim.wait(600)
  assert(
    view.panel.cur_item[1].commit.hash == selected and view.panel.cur_item[2].path == selected_path,
    "History preserves selected commit and file"
  )
  require("diffview").close()
  vim.wait(300)
  local picker = review.commits()
  wait(function()
    return picker.shown and #picker:items() > 0 and not picker:is_active()
  end, "Commit picker ready", 5000)
  local commit = picker:current().commit
  count = #picker:items()
  write("two.txt", "another commit")
  git("commit", "-am", "picker entry")
  wait(function()
    return #picker:items() == count + 1 and not picker:is_active() and not picker.neon_refreshing
  end, "Open commit picker refreshes")
  assert(picker:current().commit == commit, "Commit picker preserves selection")
  picker:close()
  vim.wait(200)
  local worktree = root .. "-worktree"
  git("worktree", "add", "-b", "agent", worktree)
  vim.cmd.edit(worktree .. "/one.txt")
  review.open(nil, worktree)
  view = lib.get_current_view()
  wait(function()
    return view.ready
  end, "Worktree view ready", 5000)
  vim.fn.writefile({ "worktree edit" }, worktree .. "/one.txt")
  wait(function()
    return #view.files.working == 1
  end, "Worktree content watcher works")
  assert(project.git(worktree, { "add", "one.txt" }))
  wait(function()
    return #view.files.staged == 1
  end, "Resolved worktree gitdir catches index changes")
  assert(git("status", "--porcelain") == "", "Worktree changes leave parent working tree/index untouched")
  vim.wait(400)
  require("diffview").close()
  vim.wait(300)
  vim.cmd.edit(root .. "/one.txt")
  git("branch", "base", "HEAD~1")
  review.open("base...HEAD")
  view = lib.get_current_view()
  wait(function()
    return view.ready and view.cur_entry
  end, "Symbolic branch review ready", 5000)
  local old_head = view.right.commit
  write("one.txt", "new committed endpoint")
  git("commit", "-am", "advance HEAD")
  wait(function()
    return view.right.commit ~= old_head
  end, "Symbolic HEAD comparison follows new commits")
  vim.wait(500)
  require("diffview").close()
  vim.wait(400)
  print(
    "PASS: initial buffer refresh, delete/recreate, nested files, inactive reviews, staging/index buffers, history and picker selection, linked worktree isolation, live symbolic HEAD review"
  )
end
local ok, err = xpcall(test, debug.traceback)
if not ok then
  io.stderr:write(err .. "\n")
  vim.cmd("cquit 1")
else
  vim.cmd("qa!")
end
