local M = { runs = {}, active = nil }
local project = require("config.project")
local api = vim.api
local script_dir = vim.fs.dirname(debug.getinfo(1, "S").source:sub(2)) .. "/../../scripts/"

local function warn(message)
  vim.notify(message, vim.log.levels.WARN)
end

local function json(path)
  return project.read(path)
end

function M.detect(file)
  if file:match("%.py$") then
    local marker = vim.fs.root(file, { "pytest.ini", "pyproject.toml", "setup.cfg", "tox.ini", ".git" })
    local root = marker or project.root(file)
    local python = root .. "/.venv/bin/python"
    if vim.fn.executable(python) ~= 1 then
      python = vim.fn.exepath("python3")
    end
    local command = { python, "-m", "pytest" }
    if vim.uv.fs_stat(root .. "/uv.lock") and vim.fn.executable("uv") == 1 then
      command = { "uv", "run", "--no-sync", "python", "-m", "pytest" }
    end
    return { kind = "pytest", root = root, command = command }
  end
  local dir = vim.fs.dirname(file)
  while dir do
    local package = json(dir .. "/package.json")
    if package then
      local dependencies = vim.tbl_extend("force", package.dependencies or {}, package.devDependencies or {})
      local kind = dependencies.vitest and "vitest" or dependencies.jest and "jest"
      if kind then
        local executable =
          vim.fs.find("node_modules/.bin/" .. kind, { path = dir, upward = true, type = "file" })[1]
        -- fs.find can exclude symlinks on some platforms; check workspace ancestors directly.
        local parent = dir
        while not executable and parent do
          local candidate = parent .. "/node_modules/.bin/" .. kind
          if vim.fn.executable(candidate) == 1 then
            executable = candidate
          end
          parent = vim.fs.dirname(parent)
          if parent == "/" then
            break
          end
        end
        if not executable then
          return nil, "Install this project’s dependencies first (" .. kind .. " is missing)"
        end
        local version = json(vim.fs.dirname(vim.uv.fs_realpath(executable)) .. "/package.json") or {}
        local major = tonumber((version.version or ""):match("^(%d+)")) or 0
        return {
          kind = kind,
          root = dir,
          command = { executable },
          separator = kind == "vitest" and major >= 5 and " > " or " ",
        }
      end
    end
    if dir == "/" then
      break
    end
    dir = vim.fs.dirname(dir)
  end
  return nil, "No pytest, Vitest or Jest project detected for this file"
end

function M.context(file, line, kind)
  local command = kind == "pytest" and { "python3", script_dir .. "test-context.py", file, tostring(line) }
    or {
      "node",
      script_dir .. "test-context.cjs",
      file,
      tostring(line),
      require("config.languages").typescript(project.root(file)),
    }
  local result = vim.system(command, { text = true }):wait(2000)
  if result.code ~= 0 then
    return nil
  end
  local ok, data = pcall(vim.json.decode, result.stdout)
  if ok and data.selector ~= vim.NIL then
    return data.selector, data.parts
  end
end

local function escape(value)
  return (
    value:gsub(".", function(char)
      return ([[\^$.*+?()[]{}|]]):find(char, 1, true) and ("\\" .. char) or char
    end)
  )
end

function M.command(adapter, targets, report, pattern)
  local args = vim.deepcopy(adapter.command)
  if adapter.kind == "pytest" then
    vim.list_extend(
      args,
      { "--color=no", "--tb=short", "--junitxml=" .. report, "-o", "junit_family=xunit1" }
    )
    vim.list_extend(args, targets)
  else
    if adapter.kind == "vitest" then
      vim.list_extend(args, { "run", "--reporter=default", "--reporter=json", "--outputFile=" .. report })
    else
      vim.list_extend(args, { "--runInBand", "--json", "--outputFile=" .. report, "--runTestsByPath" })
    end
    vim.list_extend(args, targets)
    if pattern then
      vim.list_extend(args, { "--testNamePattern", pattern })
    end
  end
  return args
end

local function report_items(adapter, report)
  local entries, failed = {}, {}
  if adapter.kind == "pytest" then
    -- Parse XML with the standard library, including escaped messages and collection failures.
    local code = [[
import json, sys, xml.etree.ElementTree as E
out=[]
for case in E.parse(sys.argv[1]).iter('testcase'):
    failure=case.find('failure')
    if failure is None: failure=case.find('error')
    if failure is not None:
        out.append(dict(file=case.get('file',''), line=int(case.get('line','0'))+1,
          name=case.get('name',''), classname=case.get('classname',''), message=failure.get('message','Test failed')))
print(json.dumps(out))
]]
    local result = vim.system({ "python3", "-c", code, report }, { text = true }):wait(2000)
    if result.code ~= 0 then
      return entries, failed
    end
    for _, case in ipairs(vim.json.decode(result.stdout)) do
      if case.file ~= "" then
        local file = vim.fs.normalize(adapter.root .. "/" .. case.file)
        local selector = case.name
        local class = case.classname:match("%.(Test[^.]+)$")
        if class then
          selector = class .. "::" .. selector
        end
        failed[#failed + 1] = { file = file, selector = selector }
        entries[#entries + 1] = { filename = file, lnum = case.line, text = case.message, type = "E" }
      else
        entries[#entries + 1] = { text = case.message, type = "E", valid = 0 }
      end
    end
  else
    local data = json(report) or {}
    for _, suite in ipairs(data.testResults or {}) do
      for _, case in ipairs(suite.assertionResults or {}) do
        if case.status == "failed" then
          local location = case.location or {}
          local message = table.concat(case.failureMessages or {}, "\n"):gsub("\27%[[%d;]*m", "")
          local line = location.line
          if not line then
            for path, n in message:gmatch("([%w_./ %-]+%.[jt]sx?):(%d+):%d+") do
              if vim.fs.basename(vim.trim(path)) == vim.fs.basename(suite.name) then
                line = tonumber(n)
                break
              end
            end
          end
          local titles = vim.deepcopy(case.ancestorTitles or {})
          titles[#titles + 1] = case.title
          failed[#failed + 1] =
            { file = suite.name, selector = table.concat(titles, adapter.separator or " ") }
          entries[#entries + 1] = {
            filename = suite.name,
            lnum = line or 1,
            text = (case.fullName or case.title) .. ": " .. message,
            type = "E",
          }
        end
      end
      if suite.status == "failed" and #(suite.assertionResults or {}) == 0 then
        entries[#entries + 1] =
          { filename = suite.name, lnum = 1, text = suite.message or "Test collection failed", type = "E" }
      end
    end
  end
  return entries, failed
end

function M.output()
  if not M.active then
    warn("No test run yet")
    return
  end
  local buf = M.active.buf
  if not api.nvim_buf_is_valid(buf) then
    return
  end
  Snacks.win({
    buf = buf,
    position = "bottom",
    height = 0.3,
    title = "Tests · " .. M.active.status,
    enter = true,
  })
end

local function start(adapter, targets, pattern)
  for _, buffer in ipairs(api.nvim_list_bufs()) do
    if
      vim.bo[buffer].modified
      and api.nvim_buf_get_name(buffer):sub(1, #adapter.root + 1) == adapter.root .. "/"
    then
      warn(
        "Save modified project buffers before testing: "
          .. vim.fn.fnamemodify(api.nvim_buf_get_name(buffer), ":t")
      )
      return
    end
  end
  if M.active and M.active.process then
    warn("Tests are running. Space p x cancels the current run.")
    return
  end
  local report = vim.fn.tempname() .. (adapter.kind == "pytest" and ".xml" or ".json")
  local command = M.command(adapter, targets, report, pattern)
  local buf = api.nvim_create_buf(false, true)
  vim.bo[buf].filetype, vim.bo[buf].bufhidden = "log", "hide"
  local run = {
    adapter = adapter,
    targets = targets,
    pattern = pattern,
    buf = buf,
    status = "running",
    failed = {},
    command = command,
    started = vim.uv.hrtime(),
  }
  M.active, M.runs[adapter.root] = run, run
  api.nvim_buf_set_lines(
    buf,
    0,
    -1,
    false,
    { "$ " .. table.concat(vim.tbl_map(vim.fn.shellescape, command), " "), "" }
  )
  local function append(_, data)
    if not data then
      return
    end
    vim.schedule(function()
      if api.nvim_buf_is_valid(buf) then
        local lines = vim.split(data:gsub("\27%[[%d;]*m", ""), "\n", { trimempty = true })
        api.nvim_buf_set_lines(buf, -1, -1, false, lines)
      end
    end)
  end
  run.process = vim.system(
    command,
    {
      cwd = adapter.root,
      text = true,
      env = { NO_COLOR = "1", FORCE_COLOR = "0", PYTHONDONTWRITEBYTECODE = "1" },
      stdout = append,
      stderr = append,
    },
    vim.schedule_wrap(function(result)
      run.process = nil
      run.status = run.cancelled and "cancelled" or result.code == 0 and "passed" or "failed"
      local data = adapter.kind ~= "pytest" and json(report) or nil
      if data then
        run.counts = {
          passed = data.numPassedTests or 0,
          failed = data.numFailedTests or 0,
          skipped = data.numPendingTests or 0,
        }
      end
      if not run.cancelled and data and (data.numPassedTests or 0) + (data.numFailedTests or 0) == 0 then
        run.status = "no tests matched"
      end
      local items, failed = report_items(adapter, report)
      run.failed = failed
      vim.fn.delete(report)
      vim.fn.setqflist({}, " ", { title = adapter.kind .. " · " .. run.status, items = items })
      if api.nvim_buf_is_valid(buf) then
        api.nvim_buf_set_lines(
          buf,
          -1,
          -1,
          false,
          { "", "Tests " .. run.status .. " (exit " .. result.code .. ")" }
        )
      end
      vim.notify(
        adapter.kind .. ": " .. run.status .. (#items > 0 and " · Space p q opens failures" or ""),
        run.status == "passed" and vim.log.levels.INFO or vim.log.levels.WARN
      )
      vim.cmd.redrawstatus()
    end)
  )
  vim.notify("Running " .. adapter.kind .. " · Space p o shows output")
  return run
end

function M.run(mode)
  local file = api.nvim_buf_get_name(0)
  if vim.bo.modified then
    warn("Save the test file before running tests")
    return
  end
  local adapter, err = M.detect(file)
  if not adapter then
    warn(err)
    return
  end
  local target = vim.fs.relpath(adapter.root, file) or file
  local pattern
  if mode == "nearest" then
    local selector, parts = M.context(file, api.nvim_win_get_cursor(0)[1], adapter.kind)
    if not selector then
      warn("No static test name at the cursor; running the current file")
    elseif adapter.kind == "pytest" then
      target = target .. "::" .. selector
    else
      pattern = "^" .. escape(parts and table.concat(parts, adapter.separator) or selector) .. "$"
    end
  end
  return start(adapter, mode == "suite" and {} or { target }, pattern)
end

function M.repeat_last(failures)
  local root = project.root()
  local run
  for dir, candidate in pairs(M.runs) do
    if dir == root or dir:sub(1, #root + 1) == root .. "/" then
      if not run or candidate.started > run.started then
        run = candidate
      end
    end
  end
  if not run then
    warn("No previous test run in this project")
    return
  end
  if not failures then
    return start(run.adapter, run.targets, run.pattern)
  end
  if #run.failed == 0 then
    warn("No individual failed tests recorded; rerun the last command with Space p l")
    return
  end
  local targets, seen, patterns = {}, {}, {}
  for _, failed in ipairs(run.failed) do
    local file = vim.fs.relpath(run.adapter.root, failed.file) or failed.file
    local target = run.adapter.kind == "pytest" and file .. "::" .. failed.selector or file
    if not seen[target] then
      targets[#targets + 1] = target
      seen[target] = true
    end
    patterns[#patterns + 1] = "^" .. escape(failed.selector) .. "$"
  end
  return start(run.adapter, targets, run.adapter.kind ~= "pytest" and table.concat(patterns, "|") or nil)
end

function M.cancel()
  if M.active and M.active.process then
    M.active.cancelled = true
    M.active.process:kill(15)
  end
end

function M.status()
  return M.active and ("Tests " .. M.active.status) or ""
end

return M
