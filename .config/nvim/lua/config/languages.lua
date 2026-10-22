local M = {}

function M.typescript(root)
  local dir = root
  while dir do
    local candidate = dir .. "/node_modules/typescript/lib/tsserver.js"
    if vim.uv.fs_stat(candidate) then
      return vim.fs.dirname(vim.fs.dirname(candidate))
    end
    if dir == "/" then
      break
    end
    dir = vim.fs.dirname(dir)
  end
  return vim.fn.stdpath("data") .. "/neon/typescript/node_modules/typescript"
end

function M.setup()
  vim.lsp.config("neon_typescript", {
    cmd = { "typescript-language-server", "--stdio" },
    filetypes = { "typescript", "typescriptreact", "javascript", "javascriptreact" },
    root_markers = { "tsconfig.json", "jsconfig.json", "package.json", ".git" },
    init_options = {
      preferences = { includeCompletionsForModuleExports = true, includeCompletionsWithInsertText = true },
    },
    before_init = function(_, config)
      config.init_options.tsserver = { path = M.typescript(config.root_dir) .. "/lib/tsserver.js" }
    end,
  })
  vim.lsp.config("neon_python", {
    cmd = { "pyright-langserver", "--stdio" },
    filetypes = { "python" },
    root_markers = { "pyrightconfig.json", "pyproject.toml", "setup.cfg", "requirements.txt", ".git" },
    settings = {
      python = {
        analysis = { autoSearchPaths = true, useLibraryCodeForTypes = true, diagnosticMode = "openFilesOnly" },
      },
    },
    before_init = function(_, config)
      local python = config.root_dir and config.root_dir .. "/.venv/bin/python"
      if python and vim.fn.executable(python) == 1 then
        config.settings.python.pythonPath = python
      end
    end,
  })
  for name, executable in pairs({
    neon_typescript = "typescript-language-server",
    neon_python = "pyright-langserver",
  }) do
    if vim.fn.executable(executable) == 1 then
      vim.lsp.enable(name)
    end
  end
  vim.api.nvim_create_autocmd("LspAttach", {
    group = vim.api.nvim_create_augroup("NeonLanguages", { clear = true }),
    callback = function(ev)
      local client = vim.lsp.get_client_by_id(ev.data.client_id)
      if not client then
        return
      end
      if client:supports_method("textDocument/completion") then
        vim.lsp.completion.enable(true, client.id, ev.buf, { autotrigger = true })
      end
      local function map(key, fn, desc, mode)
        vim.keymap.set(mode or "n", key, fn, { buffer = ev.buf, desc = desc })
      end
      map("gd", vim.lsp.buf.definition, "Go to definition")
      map("gD", vim.lsp.buf.declaration, "Go to declaration")
      map("gr", vim.lsp.buf.references, "Find references")
      map("gi", vim.lsp.buf.implementation, "Go to implementation")
      map("gy", vim.lsp.buf.type_definition, "Go to type definition")
      map("K", vim.lsp.buf.hover, "Documentation")
      map("<leader>cn", vim.lsp.buf.rename, "Rename symbol across project")
      map("<leader>ca", vim.lsp.buf.code_action, "Code action / supported quick fix", { "n", "x" })
      map("<leader>cs", function()
        Snacks.picker.lsp_symbols()
      end, "Find symbols in file")
      map("<leader>cS", function()
        Snacks.picker.lsp_workspace_symbols()
      end, "Find project symbols")
      map("<leader>cd", vim.diagnostic.open_float, "Explain diagnostic")
      map("<leader>cf", function()
        vim.lsp.buf.format({ async = true })
      end, "Format with attached server")
      map("<C-Space>", vim.lsp.completion.get, "Complete from language server", "i")
      map("<C-y>", "<C-y>", "Accept completion", "i")
      map("<C-k>", vim.lsp.buf.signature_help, "Signature help", "i")
    end,
  })
end

return M
