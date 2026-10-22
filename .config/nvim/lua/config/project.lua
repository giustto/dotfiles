local M = {}
local cache = {}

function M.root(path)
  if not path then
    local lib = package.loaded["diffview.lib"]
    local view = lib and lib.get_current_view()
    if view then
      return view.adapter.ctx.toplevel
    end
    if _G.Snacks then
      for _, picker in ipairs(Snacks.picker.get()) do
        if picker:is_focused() then
          path = picker:cwd()
          break
        end
      end
    end
    path = path or vim.api.nvim_buf_get_name(0)
  end
  if path == "" or path:match("^%w+://") then
    path = vim.fn.getcwd()
  end
  path = vim.uv.fs_realpath(path) or vim.fs.normalize(path)
  local stat = vim.uv.fs_stat(path)
  local dir = stat and stat.type == "directory" and path or vim.fs.dirname(path)
  if cache[dir] then
    return cache[dir]
  end
  local result = vim.system({ "git", "-C", dir, "rev-parse", "--show-toplevel" }, { text = true }):wait(1500)
  local root = result.code == 0 and vim.trim(result.stdout) or dir
  cache[dir] = root
  return root
end

function M.git(root, args, opts)
  local command = { "git", "-C", root }
  vim.list_extend(command, args)
  local result = vim.system(command, vim.tbl_extend("force", { text = true }, opts or {})):wait(30000)
  if result.code ~= 0 then
    return nil, vim.trim(result.stderr or "Git command failed")
  end
  return vim.trim(result.stdout)
end

function M.key(root)
  return vim.fn.sha256(root):sub(1, 24)
end

function M.state_path(kind, root)
  local dir = vim.fn.stdpath("state") .. "/neon/" .. kind
  vim.fn.mkdir(dir, "p", "0700")
  return dir .. "/" .. M.key(root) .. ".json"
end

function M.read(path)
  local ok, data = pcall(function()
    return vim.json.decode(
      table.concat(vim.fn.readfile(path), "\n"),
      { luanil = { object = true, array = true } }
    )
  end)
  return ok and data or nil
end

function M.write(path, data)
  local temp = path .. "." .. vim.uv.os_getpid() .. ".tmp"
  vim.fn.writefile({ vim.json.encode(data) }, temp)
  vim.uv.fs_chmod(temp, 384)
  assert(vim.uv.fs_rename(temp, path))
end

return M
