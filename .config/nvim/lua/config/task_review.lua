local M = {}
local project = require("config.project")
local busy = {}
local indexes = {}

local function state(root)
  root = vim.uv.fs_realpath(root) or root
  return project.read(project.state_path("reviews", root)) or { root = root, marks = {} }
end

function M.baseline(root)
  return state(root).baseline
end

function M.capture(root, name, callback)
  root = vim.uv.fs_realpath(root or project.root()) or root
  if busy[root] then
    vim.notify("A review baseline is already being captured", vim.log.levels.WARN)
    return
  end
  for _, buf in ipairs(vim.api.nvim_list_bufs()) do
    if vim.bo[buf].modified and vim.bo[buf].buftype == "" then
      local path = vim.api.nvim_buf_get_name(buf)
      if path:sub(1, #root + 1) == root .. "/" then
        vim.notify(
          "Save local edits before capturing a disk baseline: " .. vim.fn.fnamemodify(path, ":t"),
          vim.log.levels.WARN
        )
        return
      end
    end
  end
  busy[root] = true
  local index = vim.fn.tempname() .. "-neon-index"
  local env = {
    GIT_INDEX_FILE = index,
    GIT_AUTHOR_NAME = "Neon review",
    GIT_AUTHOR_EMAIL = "review@localhost",
    GIT_COMMITTER_NAME = "Neon review",
    GIT_COMMITTER_EMAIL = "review@localhost",
  }
  local function finish(err, baseline)
    busy[root] = nil
    vim.fn.delete(index)
    vim.fn.delete(index .. ".lock")
    if err then
      vim.notify("Could not capture baseline: " .. err, vim.log.levels.ERROR)
    else
      vim.notify("Review baseline saved: " .. baseline.name .. " · " .. baseline.commit:sub(1, 8))
    end
    if callback then
      callback(baseline, err)
    end
  end
  local function run(args, cb, stdin)
    local command = { "git", "-C", root }
    vim.list_extend(command, args)
    vim.system(
      command,
      { text = true, env = env, stdin = stdin },
      vim.schedule_wrap(function(result)
        if result.code ~= 0 then
          finish(vim.trim(result.stderr or "Git failed"))
          return
        end
        cb(vim.trim(result.stdout))
      end)
    )
  end
  local head = project.git(root, { "rev-parse", "--verify", "HEAD" })
  local read_tree = head and { "read-tree", head } or { "read-tree", "--empty" }
  run(read_tree, function()
    run({ "add", "-A", "--", "." }, function()
      run({ "write-tree" }, function(tree)
        local args = { "commit-tree", tree }
        if head then
          vim.list_extend(args, { "-p", head })
        end
        run(args, function(commit)
          local ref = "refs/neon/reviews/" .. project.key(root) .. "/baseline"
          run({ "update-ref", ref, commit }, function()
            local data = state(root)
            data.baseline = {
              commit = commit,
              tree = tree,
              head = head,
              name = name or "Agent task",
              time = os.time(),
              ref = ref,
            }
            data.marks = {}
            project.write(project.state_path("reviews", root), data)
            finish(nil, data.baseline)
          end)
        end, "Neon review baseline: " .. (name or "Agent task") .. "\n")
      end)
    end)
  end)
end

local function current()
  local lib = package.loaded["diffview.lib"]
  return lib and lib.get_current_view()
end

local function scope(view)
  return view.rev_arg or (view.right.type == 3 and "staged" or "working")
end

local function file_key(view, entry)
  return scope(view) .. "\n" .. entry.kind .. "\n" .. entry.path
end

local function fingerprint(view, entry)
  local root = view.adapter.ctx.toplevel
  local left, right = entry.revs.a or view.left, entry.revs.b or view.right
  local local_file, staged = right.type == 1, left.type == 3 or right.type == 3
  local function stamp(path)
    local stat = vim.uv.fs_lstat(path)
    return stat and table.concat({ stat.mtime.sec, stat.mtime.nsec, stat.size, stat.ino, stat.mode }, ":")
      or "<absent>"
  end
  local index_stamp = staged and stamp(view.adapter.ctx.dir .. "/index") or ""
  local signature = table.concat({
    local_file and stamp(root .. "/" .. entry.path) or "",
    index_stamp,
    left.commit or "",
    right.commit or "",
    entry.oldpath or "",
  }, "\n")
  view.neon_fingerprints = view.neon_fingerprints or {}
  local key = file_key(view, entry)
  local cached = view.neon_fingerprints[key]
  if cached and cached.signature == signature then
    return cached.hash
  end
  local bytes, mode = "", ""
  if local_file then
    local path = root .. "/" .. entry.path
    local stat = vim.uv.fs_lstat(path)
    mode = stat and tostring(stat.mode) or "<absent>"
    if stat and stat.type == "link" then
      bytes = vim.uv.fs_readlink(path) or "<unreadable link>"
    else
      bytes = project.git(root, { "hash-object", "--no-filters", "--", entry.path }) or "<deleted>"
    end
  end
  local index = ""
  if staged then
    if not indexes[root] or indexes[root].stamp ~= index_stamp then
      local blobs = {}
      local output = project.git(root, { "ls-files", "--stage", "-z" }) or ""
      for file_mode, hash, stage, path in output:gmatch("(%d+) ([%x]+) (%d)\t([^%z]+)%z") do
        blobs[stage .. ":" .. path] = file_mode .. ":" .. hash
      end
      indexes[root] = { stamp = index_stamp, blobs = blobs }
    end
    index = indexes[root].blobs["0:" .. entry.path] or "<absent>"
  end
  local hash = vim.fn.sha256(
    table.concat({ bytes, mode, index, left.commit or "", right.commit or "", entry.oldpath or "" }, "\n")
  )
  view.neon_fingerprints[key] = { signature = signature, hash = hash }
  return hash
end

function M.entries(view)
  view = view or current()
  if not view or not view.files then
    return {}
  end
  return view.panel:ordered_file_list()
end

function M.progress(view)
  view = view or current()
  if not view or not view.files then
    return
  end
  local data = state(view.adapter.ctx.toplevel)
  local done, total, dirty = 0, 0, false
  for _, entry in ipairs(M.entries(view)) do
    total = total + 1
    local key = file_key(view, entry)
    local mark = data.marks[key]
    if mark and mark ~= fingerprint(view, entry) then
      data.marks[key] = nil
      dirty = true
      mark = nil
    end
    entry.neon_reviewed = mark ~= nil
    if mark then
      done = done + 1
    end
  end
  if dirty then
    project.write(project.state_path("reviews", data.root), data)
  end
  view.neon_progress = { done = done, total = total }
  return view.neon_progress
end

function M.next()
  local view = current()
  if not view or not view.files then
    return
  end
  M.progress(view)
  local entries = M.entries(view)
  local start = 0
  for i, entry in ipairs(entries) do
    if entry == view.cur_entry then
      start = i
      break
    end
  end
  for n = 1, #entries do
    local entry = entries[(start + n - 1) % #entries + 1]
    if not entry.neon_reviewed then
      view:set_file(entry, true)
      return entry
    end
  end
  vim.notify("All current changes have been reviewed")
end

function M.mark(unmark)
  local view = current()
  if not view or not view.files then
    vim.notify("Open a working-tree or commit review first")
    return
  end
  local entry = view:infer_cur_file() or view.cur_entry
  if not entry or not entry.path then
    return
  end
  local root = view.adapter.ctx.toplevel
  for _, buf in ipairs(vim.api.nvim_list_bufs()) do
    if vim.api.nvim_buf_get_name(buf) == root .. "/" .. entry.path and vim.bo[buf].modified then
      vim.notify("Save this file before marking its disk changes reviewed", vim.log.levels.WARN)
      return
    end
  end
  local data = state(root)
  data.marks[file_key(view, entry)] = not unmark and fingerprint(view, entry) or nil
  project.write(project.state_path("reviews", root), data)
  M.progress(view)
  vim.cmd.redrawstatus()
  if not unmark then
    M.next()
  end
end

function M.queue()
  local view = current()
  if not view or not view.files then
    vim.notify("Open a review first")
    return
  end
  M.progress(view)
  local items = {}
  for _, entry in ipairs(M.entries(view)) do
    items[#items + 1] = { text = (entry.neon_reviewed and "✓ " or "○ ") .. entry.path, entry = entry }
  end
  vim.ui.select(items, {
    prompt = "Review progress",
    format_item = function(item)
      return item.text
    end,
  }, function(item)
    if item and vim.api.nvim_tabpage_is_valid(view.tabpage) then
      view:set_file(item.entry, true)
    end
  end)
end

function M.status()
  local view = current()
  local p = view and view.neon_progress
  return p and ("Review " .. p.done .. "/" .. p.total) or ""
end

function M.setup()
  vim.api.nvim_create_autocmd("User", {
    pattern = "DiffviewViewOpened",
    group = vim.api.nvim_create_augroup("NeonReviewProgress", { clear = true }),
    callback = function()
      local view = current()
      if view then
        view.emitter:on("files_updated", function()
          if vim.api.nvim_tabpage_is_valid(view.tabpage) then
            M.progress(view)
          end
        end)
      end
    end,
  })
end

return M
