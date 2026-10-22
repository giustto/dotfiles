local M = {}

local function git(root, args)
  local command = { "git", "-C", root }
  vim.list_extend(command, args)
  local result = vim.system(command, { text = true }):wait(3000)
  if result.code == 0 then
    return vim.trim(result.stdout)
  end
end

function M.root()
  local lib = package.loaded["diffview.lib"]
  local view = lib and lib.get_current_view()
  if view then
    return view.adapter.ctx.toplevel
  end
  local name = vim.api.nvim_buf_get_name(0)
  local dir = vim.bo.buftype == "" and name ~= "" and vim.fs.dirname(name) or vim.fn.getcwd()
  if _G.Snacks then
    for _, picker in ipairs(Snacks.picker.get()) do
      if picker:is_focused() then
        dir = picker:cwd()
        break
      end
    end
  end
  return git(dir, { "rev-parse", "--show-toplevel" })
end

local function repo()
  local root = M.root()
  if not root then
    vim.notify("Open a file or directory inside a Git repository", vim.log.levels.WARN)
  end
  return root
end

function M.open(revision, root, extra)
  root = root or repo()
  if not root then
    return
  end
  require("lazy").load({ plugins = { "diffview.nvim" } })
  local args = { "-C=" .. root }
  if revision then
    args[#args + 1] = revision
  end
  vim.list_extend(args, extra or {})
  require("diffview").open(args)
end

function M.history(file, range)
  local root = repo()
  if not root then
    return
  end
  local name = vim.api.nvim_buf_get_name(0)
  if file and (vim.bo.buftype ~= "" or name == "") then
    return
  end
  require("lazy").load({ plugins = { "diffview.nvim" } })
  local args = { "-C=" .. root }
  if range then
    args[#args + 1] = "--range=" .. range
  end
  if file then
    args[#args + 1] = name
  end
  require("diffview").file_history(nil, args)
end

function M.branches()
  local root = repo()
  if not root then
    return
  end
  return Snacks.picker.git_branches({
    cwd = root,
    all = true,
    title = "Review HEAD against branch (merge base)",
    confirm = function(picker, item)
      if not item or not item.branch then
        return
      end
      picker:close()
      -- Finish picker cleanup before Diffview runs its synchronous Git jobs.
      vim.schedule(function()
        M.open(item.branch .. "...HEAD", root)
      end)
    end,
    -- This picker selects a review base. Branch management lives in lazygit.
    win = { input = { keys = { ["<c-a>"] = false, ["<c-x>"] = false } } },
  })
end

function M.commits()
  local root = repo()
  if not root then
    return
  end
  return Snacks.picker.git_log({
    cwd = root,
    title = "Commits · Enter reviews patch",
    live = false,
    confirm = function(picker, item)
      if not item then
        return
      end
      picker:close()
      vim.schedule(function()
        M.open(item.commit .. "^!", root)
      end)
    end,
  })
end

function M.base()
  local root = repo()
  if not root then
    return
  end
  local base = git(root, { "symbolic-ref", "--quiet", "refs/remotes/origin/HEAD" })
  if not base then
    for _, ref in ipairs({ "main", "master" }) do
      if git(root, { "rev-parse", "--verify", ref .. "^{commit}" }) then
        base = ref
        break
      end
    end
  end
  vim.ui.input({ prompt = "Review base (branch, tag or commit): ", default = base or "" }, function(ref)
    if not ref or ref == "" then
      return
    end
    local sha = git(root, { "rev-parse", "--verify", "--end-of-options", ref .. "^{commit}" })
    if not sha then
      vim.notify("Not a valid commit: " .. ref, vim.log.levels.ERROR)
      return
    end
    M.open(sha .. "...HEAD", root)
  end)
end

function M.checkpoint()
  local root = repo()
  if not root then
    return
  end
  vim.ui.input({ prompt = "Agent task baseline name: ", default = "Agent task" }, function(name)
    if name and name ~= "" then
      require("config.task_review").capture(root, name)
    end
  end)
end

function M.since_checkpoint()
  local root = repo()
  if not root then
    return
  end
  local baseline = require("config.task_review").baseline(root)
  if not baseline then
    vim.notify("Set a checkpoint with Space r m before running your agent", vim.log.levels.WARN)
    return
  end
  if not git(root, { "cat-file", "-e", baseline.commit .. "^{commit}" }) then
    vim.notify("The saved baseline is missing from Git; capture it again with Space r m", vim.log.levels.WARN)
    return
  end
  M.open(baseline.commit, root)
  local view = require("diffview.lib").get_current_view()
  if view and view.left.commit == baseline.commit then
    require("config.checkpoint").attach(view, baseline)
  end
end

return M
