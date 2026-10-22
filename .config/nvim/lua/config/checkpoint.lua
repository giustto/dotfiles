local M = {}

-- A commit-to-worktree diff uses Git's index to decide which paths exist.
-- Seed a private query index from the checkpoint so baseline-only untracked
-- paths compare correctly, then include new paths with intent-to-add.
function M.attach(view, baseline)
  local async = require("diffview.async")
  local DiffView = require("diffview.scene.views.diff.diff_view").DiffView
  local FileDict = require("diffview.vcs.file_dict").FileDict
  local adapter = view.adapter
  view.get_updated_files = async.wrap(function(self, callback)
    -- Separate indices also keep overlapping refresh requests independent.
    local index = vim.fn.tempname() .. "-checkpoint-index"
    local command = { "env", "GIT_INDEX_FILE=" .. index }
    vim.list_extend(command, adapter:get_command())
    local query = setmetatable({
      get_command = function()
        return command
      end,
    }, { __index = adapter })
    local run = async.wrap(function(args, cb)
      local cmd = { "git", "-C", adapter.ctx.toplevel }
      vim.list_extend(cmd, args)
      vim.system(cmd, { text = true, env = { GIT_INDEX_FILE = index } }, vim.schedule_wrap(cb))
    end, 2)
    local function finish(err, files)
      vim.fn.delete(index)
      vim.fn.delete(index .. ".lock")
      callback(err, files)
    end
    for _, args in ipairs({ { "read-tree", baseline.commit }, { "add", "--intent-to-add", "-A", "--", "." } }) do
      local result = async.await(run(args))
      if result.code ~= 0 or self.closing:check() then
        finish({ vim.trim(result.stderr or "Checkpoint view closed") })
        return
      end
    end
    local args = adapter:rev_to_args(self.left, self.right)
    vim.list_extend(args, { "--" })
    vim.list_extend(args, self.path_args or {})
    local err, files, conflicts = async.await(query:tracked_files(self.left, self.right, args, "working", {
      default_layout = DiffView.get_default_layout(),
      merge_layout = DiffView.get_default_merge_layout(),
    }))
    async.await(async.scheduler())
    if err then
      finish(err)
      return
    end
    local result = FileDict()
    result:set_working(files)
    result:set_conflicting(conflicts)
    -- Only list queries use the private index. File reads, editing and explicit
    -- Git actions retain the original adapter and the user's real index.
    for _, entry in result:iter() do
      entry.adapter = adapter
      for _, file in ipairs(entry.layout:files()) do
        file.adapter = adapter
      end
    end
    result:update_file_trees()
    finish(nil, result)
  end, 2)
end

return M
