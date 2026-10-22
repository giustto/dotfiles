local function test()
  local api = vim.api
  vim.o.columns, vim.o.lines = 125, 38
  local messages, errors = {}, {}
  local notify = vim.notify
  vim.notify = function(message, level, opts)
    messages[#messages + 1] = tostring(message)
    if level == vim.log.levels.ERROR then
      errors[#errors + 1] = tostring(message)
    end
    notify(message, level, opts)
  end
  local function wait(predicate, message, timeout)
    assert(vim.wait(timeout or 5000, predicate, 20), message)
  end
  local root = vim.fn.tempname() .. " productivity project"
  vim.fn.mkdir(root, "p")
  local project = require("config.project")
  local function git(...)
    local result, err = project.git(root, { ... })
    assert(result, err)
    return result
  end
  local function write(name, lines)
    vim.fn.writefile(lines, root .. "/" .. name)
  end
  git("init", "-b", "main")
  git("config", "user.name", "Productivity test")
  git("config", "user.email", "test@example.invalid")
  write("one.txt", { "original" })
  write("two.txt", { "second" })
  write(".gitignore", { "ignored.txt", "node_modules/", ".venv/" })
  git("add", ".")
  git("commit", "-m", "Initial fixture")
  write("one.txt", { "existing staged edit" })
  git("add", "one.txt")
  write("two.txt", { "existing unstaged edit" })
  write("untracked.txt", { "existing untracked" })
  write("ignored.txt", { "ignored" })
  local before = git("status", "--porcelain")
  local index = git("write-tree")
  local head = git("rev-parse", "HEAD")
  vim.cmd.cd(root)
  vim.cmd.edit(vim.fn.fnameescape(root .. "/one.txt"))
  local task = require("config.task_review")
  local baseline
  task.capture(root, "Agent implementation", function(value)
    baseline = value
  end)
  wait(function()
    return baseline ~= nil
  end, "Task baseline captured")
  assert(
    git("status", "--porcelain") == before and git("write-tree") == index,
    "Capture preserves real index and working tree"
  )
  assert(git("rev-parse", "HEAD") == head, "Capture leaves branch HEAD untouched")
  assert(
    git("show", baseline.commit .. ":one.txt") == "existing staged edit",
    "Baseline includes staged edits"
  )
  assert(
    git("show", baseline.commit .. ":two.txt") == "existing unstaged edit",
    "Baseline includes unstaged edits"
  )
  assert(
    git("show", baseline.commit .. ":untracked.txt") == "existing untracked",
    "Baseline includes untracked files"
  )
  local ignored = project.git(root, { "cat-file", "-e", baseline.commit .. ":ignored.txt" })
  assert(ignored == nil, "Ignored files excluded from baseline")
  package.loaded["config.task_review"] = nil
  task = require("config.task_review")
  assert(task.baseline(root).commit == baseline.commit, "Baseline survives module/session reload")
  write("one.txt", { "agent refinement" })
  write("new.txt", { "agent file" })
  require("config.review").since_checkpoint()
  local lib = require("diffview.lib")
  local view = lib.get_current_view()
  wait(function()
    return view.ready and view.cur_entry and view.files:len() == 2
  end, "Task review excludes earlier edits")
  vim.wait(500)
  task.mark()
  assert(task.progress(view).done == 1, "Mark reviewed advances and records progress")
  package.loaded["config.task_review"] = nil
  task = require("config.task_review")
  assert(task.progress(view).done == 1, "Review marks survive reloading the state reader")
  local reviewed
  for _, entry in ipairs(task.entries(view)) do
    if entry.neon_reviewed then
      reviewed = entry
    end
  end
  assert(reviewed, "Reviewed entry found")
  write(reviewed.path, { "later agent modification" })
  wait(function()
    return task.progress(view).done == 0
  end, "Later edits invalidate review mark")
  vim.wait(500)
  require("diffview").close()
  vim.wait(300)
  vim.cmd.edit(vim.fn.fnameescape(root .. "/one.txt"))
  local buf = api.nvim_get_current_buf()
  require("config.refresh").reconcile()
  local function text()
    return api.nvim_buf_get_lines(buf, 0, 1, false)[1]
  end
  local began = vim.uv.hrtime()
  write("one.txt", { "live external content" })
  wait(function()
    return text() == "live external content"
  end, "Buffer refreshes without focus change", 1800)
  local latency = math.floor((vim.uv.hrtime() - began) / 1e6)
  write("atomic.tmp", { "same atomic content!!" })
  assert(vim.uv.fs_rename(root .. "/atomic.tmp", root .. "/one.txt"))
  wait(function()
    return text() == "same atomic content!!"
  end, "Atomic replacement refreshes buffer", 1800)
  api.nvim_buf_set_lines(buf, 0, -1, false, { "unsaved local edit" })
  write("one.txt", { "external conflict" })
  wait(function()
    return vim.b[buf].neon_external_change
  end, "Dirty buffer conflict is surfaced", 1800)
  assert(text() == "unsaved local edit" and vim.bo[buf].modified, "Dirty buffer is never overwritten")
  vim.bo[buf].modified = false
  vim.cmd.edit()
  vim.wait(200)
  local reading = require("config.reading")
  vim.wo.scrollbind = false
  vim.cmd.vsplit()
  local second = api.nvim_get_current_win()
  vim.wo.cursorbind = true
  reading.toggle_sync()
  vim.cmd.vsplit()
  local third = api.nvim_get_current_win()
  vim.wait(100)
  assert(vim.wo[third].scrollbind, "New split joins scroll synchronization")
  reading.toggle_sync()
  for _, win in ipairs(api.nvim_tabpage_list_wins(0)) do
    if api.nvim_win_get_config(win).relative == "" then
      assert(not vim.wo[win].scrollbind, "Every file split unbinds")
    end
  end
  assert(vim.wo[second].cursorbind, "Previous cursorbind restored")
  reading.toggle_sync()
  vim.cmd.vsplit()
  local helper = api.nvim_get_current_win()
  local helper_buf = api.nvim_create_buf(false, true)
  vim.bo[helper_buf].buftype = "nofile"
  api.nvim_win_set_buf(helper, helper_buf)
  vim.wait(80)
  assert(not vim.wo[helper].scrollbind, "New helper windows do not retain inherited scroll binding")
  reading.toggle_sync()
  api.nvim_win_close(helper, true)
  api.nvim_win_close(third, true)
  api.nvim_win_close(second, true)

  local fixture = "/tmp/dotfiles-productivity-fixture"
  assert(vim.fn.executable(fixture .. "/.venv/bin/python") == 1, "Install isolated runner fixtures first")
  assert(vim.uv.fs_symlink(fixture .. "/.venv", root .. "/.venv"))
  write("pyproject.toml", { "[tool.pytest.ini_options]", 'testpaths = ["."]' })
  write("test_example.py", {
    "class TestMath:",
    "    def test_good(self):",
    "        assert 1 == 1",
    "",
    "    def test_bad(self):",
    "        assert 1 == 2",
  })
  local testing = require("config.testing")
  vim.cmd.edit(vim.fn.fnameescape(root .. "/test_example.py"))
  api.nvim_win_set_cursor(0, { 6, 0 })
  assert(
    testing.context(root .. "/test_example.py", 6, "pytest") == "TestMath::test_bad",
    "Python AST finds class/test selector"
  )
  local run = testing.run("nearest")
  wait(function()
    return not run.process
  end, "Nearest pytest completes", 15000)
  assert(
    run.status == "failed" and #run.failed == 1 and #vim.fn.getqflist() == 1,
    "pytest failure produces quickfix and rerun selector: "
      .. vim.inspect({
        run = run,
        output = api.nvim_buf_get_lines(run.buf, 0, -1, false),
        quickfix = vim.fn.getqflist(),
      })
  )
  assert(run.targets[1]:match("::TestMath::test_bad$"), "Nearest run selects one test")
  write("test_example.py", {
    "class TestMath:",
    "    def test_good(self):",
    "        assert 1 == 1",
    "",
    "    def test_bad(self):",
    "        assert 1 == 1",
  })
  run = testing.repeat_last(true)
  wait(function()
    return not run.process
  end, "Failed pytest reruns", 15000)
  assert(
    run.status == "passed" and #vim.fn.getqflist() == 0,
    "Rerun clears fixed failures: " .. vim.inspect(api.nvim_buf_get_lines(run.buf, 0, -1, false))
  )
  assert(vim.uv.fs_symlink(fixture .. "/node_modules", root .. "/node_modules"))
  write("package.json", { '{"type":"module","devDependencies":{"vitest":"*"}}' })
  write("example.test.ts", {
    'import { describe, it, expect } from "vitest";',
    'describe("refinement", () => {',
    '  it("good", () => expect(1).toBe(1));',
    '  it("bad [literal]", () => expect(1).toBe(2));',
    "});",
  })
  vim.cmd.edit(vim.fn.fnameescape(root .. "/example.test.ts"))
  api.nvim_win_set_cursor(0, { 4, 0 })
  assert(
    testing.context(root .. "/example.test.ts", 4, "vitest") == "refinement bad [literal]",
    "TypeScript AST finds nested static test"
  )
  run = testing.run("nearest")
  wait(function()
    return not run.process
  end, "Nearest Vitest completes", 20000)
  assert(
    run.status == "failed" and #run.failed == 1 and #vim.fn.getqflist() == 1,
    "Vitest JSON creates navigable failure: "
      .. vim.inspect({
        targets = run.targets,
        pattern = run.pattern,
        failed = run.failed,
        output = api.nvim_buf_get_lines(run.buf, 0, -1, false),
      })
  )
  write("example.test.ts", {
    'import { describe, it, expect } from "vitest";',
    'describe("refinement", () => {',
    '  it("good", () => expect(1).toBe(1));',
    '  it("bad [literal]", () => expect(1).toBe(1));',
    "});",
  })
  run = testing.repeat_last(true)
  wait(function()
    return not run.process
  end, "Failed Vitest reruns", 20000)
  assert(run.status == "passed", "Failed Vitest selector matches literal regex characters")
  assert(
    run.counts.passed == 1 and run.counts.skipped == 1,
    "Failed-test rerun executes the selected test rather than skipping everything"
  )
  write("package.json", { '{"devDependencies":{"jest":"*"}}' })
  write(
    "example.test.cjs",
    { 'describe("manual", () => {', '  test("bad", () => expect(1).toBe(2));', "});" }
  )
  vim.cmd.edit(vim.fn.fnameescape(root .. "/example.test.cjs"))
  api.nvim_win_set_cursor(0, { 2, 0 })
  run = testing.run("nearest")
  wait(function()
    return not run.process
  end, "Jest completes", 20000)
  assert(run.status == "failed" and #run.failed == 1, "Jest adapter collects failures")
  write(
    "example.test.cjs",
    { 'describe("manual", () => {', '  test("bad", () => expect(1).toBe(1));', "});" }
  )
  run = testing.repeat_last(true)
  wait(function()
    return not run.process
  end, "Jest failed-test rerun completes", 20000)
  assert(run.status == "passed" and run.counts.passed == 1, "Jest rerun executes fixed failure")
  write(
    "example.test.cjs",
    { 'test("slow", async () => { await new Promise(resolve => setTimeout(resolve, 10000)); });' }
  )
  run = testing.run("file")
  testing.cancel()
  wait(function()
    return not run.process
  end, "Cancelled test process exits", 5000)
  assert(run.status == "cancelled", "Cancellation remains visible")
  assert(#errors == 0, table.concat(errors, "\n"))
  assert(vim.v.errmsg == "", vim.v.errmsg)
  print(
    "PASS: exact durable baselines, real-index safety, content-aware review progress, live/atomic refresh ("
      .. latency
      .. " ms), dirty-buffer safety, new-split sync cleanup, real pytest/Vitest/Jest nearest tests and failed-test reruns"
  )
end

local ok, err = xpcall(test, debug.traceback)
if not ok then
  io.stderr:write(err .. "\n")
  vim.cmd("cquit 1")
else
  vim.cmd("qa!")
end
