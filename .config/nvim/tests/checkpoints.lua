local function test()
  vim.o.columns, vim.o.lines = 130, 40
  local api, uv = vim.api, vim.uv
  local root = uv.fs_realpath(vim.env.NEON_REVIEW_TEST_ROOT)
  local phase = vim.env.NEON_REVIEW_TEST_PHASE
  local task = require("config.task_review")
  local project = require("config.project")
  local notices = {}
  local function wait(predicate, message)
    if not vim.wait(6000, predicate, 20) then
      local view = require("diffview.lib").get_current_view()
      error(message .. vim.inspect({
        notices = notices,
        view = view and {
          ready = view.ready,
          current = view.cur_entry and view.cur_entry.path,
          files = vim.tbl_map(function(entry)
            return entry.path
          end, task.entries(view)),
        },
      }))
    end
  end
  local function git(...)
    local result, err = project.git(root, { ... })
    assert(result, err)
    return result
  end
  vim.notify = function(message, level)
    notices[#notices + 1] = tostring(message)
    assert(level ~= vim.log.levels.ERROR, tostring(message))
  end
  vim.cmd.cd(root)
  vim.cmd.edit(vim.fn.fnameescape(root .. "/tracked.txt"))
  if phase == "capture" then
    api.nvim_buf_set_lines(0, 0, -1, false, { "unsaved refinement" })
    task.capture(root, "Refuse unsaved content")
    assert(not task.baseline(root), "Unsaved buffers block checkpoint capture")
    assert(notices[#notices]:find("Save local edits", 1, true), "Unsaved capture explains recovery")
    vim.cmd("edit!")
    local captured
    task.capture(root, "Agent validation", function(value)
      captured = value
    end)
    wait(function()
      return captured ~= nil
    end, "Checkpoint captured")
    for _, name in ipairs({ "staged", "unstaged", "untracked" }) do
      assert(git("show", captured.commit .. ":" .. name .. ".txt") == "before agent " .. name)
    end
    assert(not project.git(root, { "cat-file", "-e", captured.commit .. ":ignored.txt" }))
    assert(git("rev-parse", captured.ref) == captured.commit, "Local ref retains snapshot")
    return
  end
  assert(task.baseline(root).name == "Agent validation", "Checkpoint survives process restart")
  require("config.review").since_checkpoint()
  local view = require("diffview.lib").get_current_view()
  wait(function()
    return view and view.ready and view.cur_entry and view.files:len() == 3
  end, "Checkpoint comparison contains only agent changes")
  vim.wait(300)
  local function focus(name)
    for _, entry in ipairs(task.entries(view)) do
      if entry.path == name then
        view:set_file(entry, true)
        vim.wait(150)
        return entry
      end
    end
    error("Missing review entry: " .. name)
  end
  local function progress()
    return task.progress(view).done
  end
  if phase == "mark" then
    focus("tracked.txt")
    local buf = api.nvim_get_current_buf()
    api.nvim_buf_set_lines(buf, 0, -1, false, { "unsaved review edit" })
    task.mark()
    assert(progress() == 0, "Unsaved content cannot be marked reviewed")
    vim.cmd("edit!")
    for _, name in ipairs({ "tracked.txt", "script.sh", "link.txt" }) do
      focus(name)
      task.mark()
    end
    assert(progress() == 3, "All changed files marked reviewed")
    focus("tracked.txt")
    task.mark(true)
    assert(progress() == 2, "Unmark reopens a reviewed file")
    task.next()
    assert(view.cur_entry.path == "tracked.txt", "Next skips already reviewed files")
    task.mark()
    assert(progress() == 3, "Re-review restores progress")
    local select = vim.ui.select
    vim.ui.select = function(items, _, callback)
      assert(#items == 3, "Queue contains all changed files")
      for _, item in ipairs(items) do
        assert(item.text:find("✓", 1, true), "Queue shows durable reviewed indicators")
      end
      callback(nil)
    end
    task.queue()
    vim.ui.select = select
  else
    assert(progress() == 3, "Review marks survive a separate Neovim process")
    local before = git("write-tree")
    vim.fn.writefile({ "new agent file" }, root .. "/new agent.txt")
    wait(function()
      return view.files:len() == 4
    end, "New untracked agent files appear in the live checkpoint review")
    vim.fn.writefile({ "agent edited existing untracked file" }, root .. "/untracked.txt")
    wait(function()
      return view.files:len() == 5
    end, "Edits to baseline untracked files appear live")
    local untracked = focus("untracked.txt")
    assert(untracked.revs.a.commit == task.baseline(root).commit, "Untracked edits retain baseline revision")
    local baseline_file = untracked.layout.a.file
    wait(function()
      return baseline_file:is_valid()
        and api.nvim_buf_get_lines(baseline_file.bufnr, 0, 1, false)[1] == "before agent untracked"
    end, "Untracked edits show the original baseline content on the left")
    assert(uv.fs_unlink(root .. "/unstaged.txt"))
    wait(function()
      return view.files:len() == 6
    end, "Deleted baseline files appear live")
    assert(progress() == 3, "Unrelated new edits preserve other reviewed marks")
    -- chmod changes Git's executable mode without changing any content bytes.
    assert(uv.fs_chmod(root .. "/script.sh", 493))
    assert(progress() == 2, "Executable-mode changes invalidate a working-file review mark")
    focus("script.sh")
    task.mark()
    assert(progress() == 3)
    -- Retargeting between equal-content files is still a meaningful Git change.
    assert(uv.fs_unlink(root .. "/link.txt"))
    assert(uv.fs_symlink("target-c.txt", root .. "/link.txt"))
    assert(progress() == 2, "Symlink target changes invalidate review even with identical target contents")
    focus("link.txt")
    task.mark()
    assert(progress() == 3)
    require("diffview").close()
    vim.wait(200)
    require("config.review").open(nil, root, { "--cached" })
    local staged_view = require("diffview.lib").get_current_view()
    wait(function()
      return staged_view and staged_view.ready and staged_view.cur_entry
    end, "Staged review opens")
    assert(task.progress(staged_view).done == 0, "Reviewed marks do not leak across review scopes")
    require("diffview").close()
    vim.wait(150)
    assert(git("write-tree") == before, "Mark/unmark/navigation leaves index untouched")
    -- Explicit staging here is confined to this temporary test repository.
    git("add", "script.sh")
    require("config.review").open(nil, root, { "--cached" })
    staged_view = require("diffview.lib").get_current_view()
    wait(function()
      return staged_view.ready and staged_view.cur_entry and staged_view.files:len() == 2
    end, "Staged file with executable mode appears")
    for _, entry in ipairs(task.entries(staged_view)) do
      if entry.path == "script.sh" then
        staged_view:set_file(entry, true)
      end
    end
    vim.wait(200)
    task.mark()
    assert(task.progress(staged_view).done == 1, "Staged file can be marked separately")
    git("update-index", "--chmod=-x", "--", "script.sh")
    assert(
      task.progress(staged_view).done == 0,
      "Staged mode changes invalidate review without content changes"
    )
    require("diffview").close()
    vim.wait(150)
    git("read-tree", before)
    local worktree = root .. " linked"
    git("worktree", "add", "-b", "agent-isolation", worktree)
    assert(not task.baseline(worktree), "Linked worktrees have independent checkpoints")
    local linked
    task.capture(worktree, "Linked task", function(value)
      linked = value
    end)
    wait(function()
      return linked ~= nil
    end, "Linked worktree checkpoint captured")
    assert(task.baseline(root).name == "Agent validation", "Linked checkpoint preserves parent checkpoint")
    assert(linked.ref ~= task.baseline(root).ref, "Linked checkpoints have separate retention refs")
    local old = task.baseline(root).commit
    local captured
    task.capture(root, "Next task", function(value)
      captured = value
    end)
    wait(function()
      return captured ~= nil
    end, "Replacement checkpoint captured")
    assert(captured.commit ~= old, "New checkpoint replaces old baseline")
    local state = project.read(project.state_path("reviews", root))
    assert(vim.tbl_isempty(state.marks), "New task starts with no old review marks")
  end
end
local ok, err = xpcall(test, debug.traceback)
if ok and vim.v.errmsg ~= "" then
  ok, err = false, vim.v.errmsg
end
if not ok then
  io.stderr:write(err .. "\n")
  vim.cmd("cquit 1")
else
  vim.cmd("qa!")
end
