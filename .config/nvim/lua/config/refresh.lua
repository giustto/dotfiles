local M = { repos = {}, watches = {}, pending = {}, stopped = false }
local uv, api = vim.uv, vim.api
local project = require("config.project")
local timer, sweep
local excluded = {
  [".git"] = true,
  node_modules = true,
  [".venv"] = true,
  venv = true,
  __pycache__ = true,
  [".mypy_cache"] = true,
  [".pytest_cache"] = true,
  [".next"] = true,
  [".cache"] = true,
  dist = true,
  build = true,
  coverage = true,
}

local function live(view)
  return view and view.ready and api.nvim_tabpage_is_valid(view.tabpage) and not view.closing:check()
end

local function snapshot()
  local saved = { focus = api.nvim_get_current_win(), wins = {} }
  for _, win in ipairs(api.nvim_tabpage_list_wins(0)) do
    saved.wins[win] = {
      buf = api.nvim_win_get_buf(win),
      name = api.nvim_buf_get_name(api.nvim_win_get_buf(win)),
      view = api.nvim_win_call(win, vim.fn.winsaveview),
    }
  end
  return saved
end

local function restore(saved)
  if api.nvim_get_current_win() ~= saved.focus then
    return
  end
  for win, data in pairs(saved.wins) do
    if api.nvim_win_is_valid(win) and api.nvim_buf_get_name(api.nvim_win_get_buf(win)) == data.name then
      api.nvim_win_call(win, function()
        vim.fn.winrestview(data.view)
      end)
    end
  end
end

local function refresh_history(view)
  if view.neon_refreshing or view.panel.updating then
    view.neon_dirty = true
    return
  end
  view.neon_refreshing, view.neon_dirty = true, false
  local saved = snapshot()
  local selected = view.panel.cur_item or {}
  local commit = selected[1] and selected[1].commit.hash
  local path = selected[2] and selected[2].path
  local folds = {}
  for _, entry in ipairs(view.panel.entries) do
    folds[entry.commit.hash] = entry.folded
  end
  view.panel:update_entries(function(entries, status)
    view.neon_refreshing = false
    if not live(view) or not view:is_cur_tabpage() or not entries or status >= 3 then
      return
    end
    local file
    for _, entry in ipairs(entries) do
      if folds[entry.commit.hash] ~= nil then
        entry.folded = folds[entry.commit.hash]
      end
      if entry.commit.hash == commit then
        for _, candidate in ipairs(entry.files) do
          if candidate.path == path then
            file = candidate
            break
          end
        end
      end
    end
    if file then
      view:set_file(file, false)
    end
    view.panel:render()
    view.panel:redraw()
    -- Attachment is asynchronous; restore only after this selection has opened.
    view.emitter:once("file_open_post", function()
      if live(view) and view:is_cur_tabpage() then
        restore(saved)
      end
    end)
    if not file then
      restore(saved)
    end
  end)
end

local function refresh_view(view, change)
  if not live(view) then
    return
  end
  if not view:is_cur_tabpage() then
    view.neon_dirty = true
    return
  end
  if not view.update_files then
    if change.refs or change.force or view.neon_dirty then
      refresh_history(view)
    end
    return
  end
  if view.neon_refreshing then
    view.neon_dirty = true
    return
  end
  if
    change.refs
    and (not view.rev_arg or view.rev_arg:find("HEAD", 1, true) or view.rev_arg:find("...", 1, true))
  then
    local old_left, old_right = view.left, view.right
    local left, right =
      view.adapter:parse_revs(view.rev_arg, { cached = not view.rev_arg and old_right.type == 3 })
    if left and right then
      view.left, view.right = left, right
      for _, entry in view.files:iter() do
        for symbol, rev in pairs(entry.revs or {}) do
          local replacement = rev == old_left and left or rev == old_right and right
          local window = entry.layout[symbol]
          if replacement and replacement.commit ~= rev.commit and window and window.file then
            local file = window.file
            if not file:is_valid() or not vim.bo[file.bufnr].modified then
              file:dispose_buffer()
              file.rev = replacement
              file.winbar = " " .. replacement:object_name(10) .. ":" .. file.path
              entry.revs[symbol] = replacement
            end
          end
        end
      end
    end
  end
  if change.git then
    -- Diffview caches index mtimes in whole seconds. Compare loaded index blobs
    -- explicitly so two stage operations in the same second cannot leave stale text.
    for _, entry in view.files:iter() do
      for _, file in ipairs(entry.layout:files()) do
        if file.rev.type == 3 and file:is_valid() and not vim.bo[file.bufnr].modified then
          local hash = view.adapter:file_blob_hash(file.path)
          if hash ~= file.blob_hash then
            file:dispose_buffer()
          end
        end
      end
    end
  end
  view.neon_refreshing, view.neon_dirty = true, false
  local saved = snapshot()
  view:update_files(function()
    view.neon_refreshing = false
    if not live(view) or not view:is_cur_tabpage() then
      return
    end
    require("config.task_review").progress(view)
    restore(saved)
    vim.cmd("redrawstatus")
  end)
end

local sources = {
  files = true,
  grep = true,
  git_files = true,
  git_grep = true,
  git_status = true,
  git_diff = true,
  git_log = true,
  git_branches = true,
  recent = true,
  buffers = true,
  qflist = true,
  loclist = true,
}

local function item_key(item)
  if not item then
    return ""
  end
  if item.commit then
    return "commit:" .. tostring(item.commit)
  end
  if item.branch then
    return "branch:" .. item.branch
  end
  if item.file then
    return item.file .. "\n" .. vim.inspect(item.pos or {})
  end
  return item.text or ""
end

local function refresh_picker(picker)
  if picker.closed then
    return
  end
  if picker.neon_refreshing then
    picker.neon_dirty = true
    return
  end
  picker.neon_refreshing = true
  local current, selected = item_key(picker:current()), {}
  for _, item in ipairs(picker:selected()) do
    selected[item_key(item)] = true
  end
  picker.list:set_target()
  picker:find({
    refresh = true,
    on_done = function()
      picker.neon_refreshing = false
      if picker.closed then
        return
      end
      local selection = {}
      for i, item in ipairs(picker:items()) do
        local key = item_key(item)
        if selected[key] then
          selection[#selection + 1] = item
        end
        if key == current then
          picker.list:set_target(i, picker.list.top, { force = true })
          picker.list:move(i, true)
        end
      end
      picker.list:set_selected(selection)
      picker.preview:refresh(picker)
      if picker.neon_dirty then
        picker.neon_dirty = false
        refresh_picker(picker)
      end
    end,
  })
end

local function stamp(stat)
  return stat and table.concat({ stat.mtime.sec, stat.mtime.nsec, stat.size, stat.ino }, ":") or "missing"
end

local function reload_buffers(root)
  for _, buf in ipairs(api.nvim_list_bufs()) do
    if api.nvim_buf_is_loaded(buf) and vim.bo[buf].buftype == "" then
      local name = api.nvim_buf_get_name(buf)
      if name:sub(1, #root + 1) == root .. "/" then
        local stat = uv.fs_stat(name)
        local previous = vim.b[buf].neon_disk_stamp
        local changed = previous and previous ~= stamp(stat)
        if changed and (vim.bo[buf].modified or not stat) then
          if not vim.b[buf].neon_external_change then
            vim.notify(
              (
                stat and "External edit conflicts with unsaved changes: "
                or "File deleted externally; buffer retained: "
              ) .. vim.fn.fnamemodify(name, ":t"),
              vim.log.levels.WARN
            )
          end
          vim.b[buf].neon_external_change = true
        elseif changed then
          local saved = snapshot()
          api.nvim_buf_call(buf, function()
            vim.cmd("silent keepalt keepjumps edit")
          end)
          restore(saved)
          vim.b[buf].neon_external_change = nil
        end
        if not vim.bo[buf].modified then
          vim.b[buf].neon_disk_stamp = stamp(stat)
        end
      end
    end
  end
end

function M.flush()
  if M.stopped then
    return
  end
  local mode = vim.fn.mode()
  local picker_input = mode:match("^i") and vim.bo.filetype == "snacks_picker_input"
  if mode:match("^[cR]") or (mode:match("^i") and not picker_input) then
    return
  end
  local pending = M.pending
  M.pending = {}
  local lib = package.loaded["diffview.lib"]
  for root, change in pairs(pending) do
    if picker_input then
      M.pending[root] = change
    else
      reload_buffers(root)
    end
    if lib and not picker_input then
      for _, view in ipairs(lib.views) do
        if view.adapter.ctx.toplevel == root then
          refresh_view(view, change)
        end
      end
    end
    if _G.Snacks then
      local git = package.loaded["snacks.explorer.git"]
      if git then
        git.refresh(root)
      end
      for _, picker in ipairs(Snacks.picker.get({ tab = false })) do
        if not picker.closed and project.root(picker:cwd()) == root then
          local source = picker.opts.source
          if source == "explorer" then
            require("snacks.explorer.tree"):refresh(root)
            refresh_picker(picker)
          elseif sources[source] then
            if not (source == "git_log" or source == "git_branches") or change.refs or change.force then
              refresh_picker(picker)
            end
          end
        end
      end
    end
    if change.git and package.loaded.gitsigns then
      require("gitsigns").refresh()
    end
  end
  vim.cmd("redrawstatus")
end

function M.request(root, change)
  if M.stopped then
    return
  end
  local pending = M.pending[root] or {}
  for key, value in pairs(change or {}) do
    pending[key] = pending[key] or value
  end
  M.pending[root] = pending
  timer:stop()
  timer:start(140, 0, vim.schedule_wrap(M.flush))
end

local function watch(path, root, kind, used, recursive)
  local key = root .. "\n" .. kind .. "\n" .. path
  used[key] = true
  if M.watches[key] then
    return
  end
  local handle = uv.new_fs_event()
  local ok = handle:start(path, { recursive = recursive or false }, function(err, name)
    if err then
      if M.repos[root] then
        M.repos[root].fallback = true
      end
      return
    end
    name = name or ""
    if kind == "tree" then
      for segment in name:gmatch("[^/]+") do
        if excluded[segment] then
          return
        end
      end
    end
    if kind == "git" then
      if name:match("%.lock$") then
        return
      end
      if
        name ~= ""
        and name ~= "HEAD"
        and name ~= "index"
        and name ~= "packed-refs"
        and not name:match("^refs[/]?")
      then
        return
      end
    end
    vim.schedule(function()
      if M.repos[root] then
        M.request(root, { git = kind == "git", refs = kind == "git" and name ~= "index" })
      end
    end)
  end)
  if ok then
    M.watches[key] = handle
  else
    handle:close()
    M.repos[root].fallback = true
  end
end

function M.reconcile()
  if M.stopped then
    return
  end
  local roots, files = {}, {}
  for _, buf in ipairs(api.nvim_list_bufs()) do
    local name = api.nvim_buf_get_name(buf)
    if
      api.nvim_buf_is_loaded(buf)
      and vim.bo[buf].buftype == ""
      and name ~= ""
      and not name:match("^%w+://")
    then
      local root = project.root(name)
      roots[root] = true
      files[#files + 1] = { path = name, root = root }
      if not vim.b[buf].neon_disk_stamp then
        vim.b[buf].neon_disk_stamp = stamp(uv.fs_stat(name))
      end
    end
  end
  local lib = package.loaded["diffview.lib"]
  if lib then
    for _, view in ipairs(lib.views) do
      roots[view.adapter.ctx.toplevel] = true
    end
  end
  if _G.Snacks then
    for _, picker in ipairs(Snacks.picker.get({ tab = false })) do
      if picker.opts.source == "explorer" or sources[picker.opts.source] then
        roots[project.root(picker:cwd())] = true
      end
    end
  end
  local used = {}
  for root in pairs(roots) do
    if not M.repos[root] then
      M.repos[root] = {}
      M.repos[root].gitdir = project.git(root, { "rev-parse", "--absolute-git-dir" })
      M.repos[root].common = project.git(root, { "rev-parse", "--path-format=absolute", "--git-common-dir" })
      M.request(root, {})
    end
    watch(root, root, "tree", used, true)
    for _, dir in ipairs({ M.repos[root].gitdir or "", M.repos[root].common or "" }) do
      if dir ~= "" then
        watch(dir, root, "git", used, true)
      end
    end
    if M.repos[root].fallback and uv.now() - (M.repos[root].last_poll or 0) >= 5000 then
      M.repos[root].last_poll = uv.now()
      M.request(root, { git = true, refs = true })
    end
  end
  for _, file in ipairs(files) do
    watch(vim.fs.dirname(file.path), file.root, "file", used, false)
  end
  for key, handle in pairs(M.watches) do
    if not used[key] then
      handle:stop()
      handle:close()
      M.watches[key] = nil
    end
  end
  for root in pairs(M.repos) do
    if not roots[root] then
      M.repos[root] = nil
    end
  end
  if lib then
    for _, view in ipairs(lib.views) do
      if view.neon_dirty and live(view) and view:is_cur_tabpage() then
        M.request(view.adapter.ctx.toplevel, { force = true })
      end
    end
  end
end

function M.force()
  M.reconcile()
  M.request(project.root(), { force = true, git = true, refs = true })
  M.flush()
end

function M.setup()
  timer, sweep = uv.new_timer(), uv.new_timer()
  local group = api.nvim_create_augroup("NeonRefresh", { clear = true })
  api.nvim_create_autocmd({ "BufReadPost", "BufNewFile" }, {
    group = group,
    callback = function(ev)
      if vim.bo[ev.buf].buftype == "" then
        vim.b[ev.buf].neon_disk_stamp = stamp(uv.fs_stat(api.nvim_buf_get_name(ev.buf)))
        vim.b[ev.buf].neon_external_change = nil
      end
    end,
  })
  api.nvim_create_autocmd({ "BufReadPost", "BufNewFile", "BufWinEnter", "TabEnter" }, {
    group = group,
    callback = function()
      vim.schedule(M.reconcile)
    end,
  })
  api.nvim_create_autocmd({ "FocusGained", "TermClose", "TermLeave" }, { group = group, callback = M.force })
  api.nvim_create_autocmd({ "InsertLeave", "CmdlineLeave" }, {
    group = group,
    callback = function()
      vim.schedule(M.flush)
    end,
  })
  api.nvim_create_autocmd("BufWritePost", {
    group = group,
    callback = function(ev)
      vim.b[ev.buf].neon_external_change = nil
      vim.b[ev.buf].neon_disk_stamp = stamp(uv.fs_stat(api.nvim_buf_get_name(ev.buf)))
      M.request(project.root(api.nvim_buf_get_name(ev.buf)), {})
    end,
  })
  api.nvim_create_autocmd("User", {
    group = group,
    pattern = { "DiffviewViewOpened", "DiffviewViewClosed", "DiffviewViewEnter" },
    callback = function()
      vim.schedule(function()
        M.reconcile()
        M.request(project.root(), { force = true })
      end)
    end,
  })
  api.nvim_create_autocmd("VimLeavePre", {
    group = group,
    callback = function()
      M.stopped = true
      timer:stop()
      timer:close()
      sweep:stop()
      sweep:close()
      for _, handle in pairs(M.watches) do
        handle:stop()
        handle:close()
      end
    end,
  })
  api.nvim_create_user_command(
    "ProjectRefresh",
    M.force,
    { desc = "Refresh project buffers, review, explorer and pickers" }
  )
  sweep:start(500, 1000, vim.schedule_wrap(M.reconcile))
  vim.schedule(M.reconcile)
end

return M
