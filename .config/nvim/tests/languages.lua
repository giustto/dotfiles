local function test()
  local root = vim.fn.tempname() .. "-languages"
  vim.fn.mkdir(root, "p")
  local function write(name, lines)
    vim.fn.writefile(lines, root .. "/" .. name)
  end
  write(
    "tsconfig.json",
    {
      '{"compilerOptions":{"strict":true,"noEmit":true,"moduleResolution":"node","target":"ES2020"},"include":["*.ts"]}',
    }
  )
  write("library.ts", { "export function calculate(value: number): number { return value + 1; }" })
  write("main.ts", { 'import { calculate } from "./library";', 'calculate("wrong type");' })
  write("pyproject.toml", { "[tool.pyright]", 'typeCheckingMode = "basic"' })
  write("helper.py", { "def calculate(value: int) -> int:", "    return value + 1" })
  write("main.py", { "from helper import calculate", 'calculate("wrong type")' })
  local function check(file, server, line, character, renamed)
    vim.cmd.edit(vim.fn.fnameescape(root .. "/" .. file))
    local buf = vim.api.nvim_get_current_buf()
    local client
    assert(
      vim.wait(20000, function()
        for _, candidate in ipairs(vim.lsp.get_clients({ bufnr = buf })) do
          if candidate.name == server and candidate.initialized then
            client = candidate
            return true
          end
        end
        return false
      end, 30),
      server .. " attaches"
    )
    assert(
      vim.wait(20000, function()
        return #vim.diagnostic.get(buf, { severity = vim.diagnostic.severity.ERROR }) > 0
      end, 30),
      server .. " reports type error"
    )
    local params =
      { textDocument = { uri = vim.uri_from_bufnr(buf) }, position = { line = line, character = character } }
    local definition = client:request_sync("textDocument/definition", params, 15000, buf)
    assert(definition and definition.result and #definition.result > 0, server .. " finds definition")
    params.context = { includeDeclaration = true }
    local refs = client:request_sync("textDocument/references", params, 15000, buf)
    assert(refs and refs.result and #refs.result >= 2, server .. " finds references")
    params.context, params.newName = nil, renamed
    local rename = client:request_sync("textDocument/rename", params, 15000, buf)
    assert(rename and rename.result, server .. " provides workspace rename")
    vim.lsp.util.apply_workspace_edit(rename.result, client.offset_encoding)
    assert(
      table.concat(vim.api.nvim_buf_get_lines(buf, 0, -1, false), "\n"):find(renamed, 1, true),
      server .. " rename updates caller"
    )
    print("PASS: " .. server .. " real diagnostics, definitions, references and workspace rename")
    for _, buffer in ipairs(vim.api.nvim_list_bufs()) do
      vim.bo[buffer].modified = false
    end
    client:stop()
  end
  check("main.ts", "neon_typescript", 1, 3, "calculateRefined")
  check("main.py", "neon_python", 1, 3, "calculate_refined")
end
local ok, err = xpcall(test, debug.traceback)
if not ok then
  io.stderr:write(err .. "\n")
  vim.cmd("cquit 1")
else
  vim.cmd("qa!")
end
