-- Set leader key
vim.g.mapleader = " "
vim.opt.fillchars:append({ eob = " " })

-- Cursor modifications
vim.opt.guicursor = {
  "n-v-c-sm:block",
  "i-ci-ve:ver25",
  "r-cr-o:hor20",
}

-- General options
vim.o.number = true
vim.o.relativenumber = true
vim.opt.wrap = false
vim.opt.smartindent = true
vim.opt.autoindent = true

-- Visual settings
vim.o.termguicolors = true
vim.o.background = "dark"

-- File handling
vim.opt.backup = false
vim.opt.writebackup = false
vim.opt.swapfile = false

-- Performance improvements
vim.opt.redrawtime = 10000
vim.opt.maxmempattern = 20000

-- Install lazy.nvim if not installed
local lazypath = vim.fn.stdpath("data") .. "/lazy/lazy.nvim"
if not vim.loop.fs_stat(lazypath) then
  vim.fn.system({
    "git",
    "clone",
    "--filter=blob:none",
    "https://github.com/folke/lazy.nvim.git",
    "--branch=stable",
    lazypath,
  })
end
vim.opt.rtp:prepend(lazypath)

-- Setup plugins
require("lazy").setup({
  {
    "rose-pine/neovim",
    name = "rose-pine",
    config = function()
      require("rose-pine").setup({
        disable_background = true,
        disable_float_background = true,
      })
      vim.cmd("colorscheme rose-pine")
    end
  },
})

-- Optional: Transparent background fallback
vim.cmd [[
  augroup TransparentBG
    autocmd!
    autocmd ColorScheme * highlight Normal guibg=NONE ctermbg=NONE
    autocmd ColorScheme * highlight NormalNC guibg=NONE ctermbg=NONE
    autocmd ColorScheme * highlight SignColumn guibg=NONE ctermbg=NONE
    autocmd ColorScheme * highlight VertSplit guibg=NONE ctermbg=NONE
  augroup END
]]

-- Diagnostic signs
local signs = {
  { name = "DiagnosticSignError", text = "✗" },
  { name = "DiagnosticSignWarn",  text = "⚠" },
  { name = "DiagnosticSignInfo",  text = "ℹ" },
  { name = "DiagnosticSignHint",  text = "💡" },
}
for _, sign in ipairs(signs) do
  vim.fn.sign_define(sign.name, { text = sign.text, texthl = sign.name, numhl = "" })
end

vim.diagnostic.config({
  virtual_text = { prefix = '●' },
  signs = true,
  underline = true,
  update_in_insert = false,
  severity_sort = true,
})

-- Function to find project root
local function find_root(patterns)
  local path = vim.fn.expand('%:p:h')
  local root = vim.fs.find(patterns, { path = path, upward = true })[1]
  return root and vim.fn.fnamemodify(root, ':h') or path
end

-- Shell LSP setup
local function setup_shell_lsp()
  vim.lsp.start({
    name = 'bashls',
    cmd = {'bash-language-server', 'start'},
    filetypes = {'sh', 'bash', 'zsh'},
    root_dir = find_root({'.git', 'Makefile'}),
    settings = {
      bashIde = {
        globPattern = "*@(.sh|.inc|.bash|.command)"
      }
    }
  })
end

-- Python LSP setup
local function setup_python_lsp()
  vim.lsp.start({
    name = 'pyright',
    cmd = {'pyright'},
    filetypes = {'python'},
    root_dir = find_root({'pyproject.toml', 'setup.py', 'setup.cfg', 'requirements.txt', '.git'}),
    settings = {
      pylsp = {
        plugins = {
          pycodestyle = { enabled = false },
          flake8 = { enabled = true },
          black = { enabled = true }
        }
      }
    }
  })
end

-- Auto-start LSPs
vim.api.nvim_create_autocmd('FileType', {
  pattern = 'sh,bash,zsh',
  callback = setup_shell_lsp,
  desc = 'Start shell LSP'
})

vim.api.nvim_create_autocmd('FileType', {
  pattern = 'python',
  callback = setup_python_lsp,
  desc = 'Start Python LSP'
})

-- Formatting logic
local function format_code()
  local bufnr = vim.api.nvim_get_current_buf()
  local filename = vim.api.nvim_buf_get_name(bufnr)
  local filetype = vim.bo[bufnr].filetype
  local cursor_pos = vim.api.nvim_win_get_cursor(0)

  if filetype == 'python' or filename:match('%.py$') then
    if filename == '' then
      print("Save the file first before formatting Python")
      return
    end
    local black_cmd = "black --quiet " .. vim.fn.shellescape(filename)
    vim.fn.system(black_cmd)
    if vim.v.shell_error == 0 then
      vim.cmd('checktime')
      vim.api.nvim_win_set_cursor(0, cursor_pos)
      print("Formatted with black")
    else
      print("No Python formatter available (install black)")
    end
    return
  end

  if filetype == 'sh' or filetype == 'bash' or filename:match('%.sh$') then
    local lines = vim.api.nvim_buf_get_lines(bufnr, 0, -1, false)
    local content = table.concat(lines, '\n')
    local cmd = {'shfmt', '-i', '2', '-ci', '-sr'}
    local result = vim.fn.system(cmd, content)
    if vim.v.shell_error == 0 then
      local formatted_lines = vim.split(result, '\n')
      if formatted_lines[#formatted_lines] == '' then
        table.remove(formatted_lines)
      end
      vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, formatted_lines)
      vim.api.nvim_win_set_cursor(0, cursor_pos)
      print("Shell script formatted with shfmt")
    else
      print("shfmt error: " .. result)
    end
    return
  end

  print("No formatter available for " .. filetype)
end

vim.api.nvim_create_user_command("FormatCode", format_code, {
  desc = "Format current file"
})

vim.keymap.set('n', '<leader>fm', format_code, { desc = 'Format file' })

-- LSP keymaps
vim.api.nvim_create_autocmd('LspAttach', {
  callback = function(event)
    local opts = {buffer = event.buf}
    vim.keymap.set('n', 'gD', vim.lsp.buf.definition, opts)
    vim.keymap.set('n', 'gs', vim.lsp.buf.declaration, opts)
    vim.keymap.set('n', 'gr', vim.lsp.buf.references, opts)
    vim.keymap.set('n', 'gi', vim.lsp.buf.implementation, opts)
    vim.keymap.set('n', 'K', vim.lsp.buf.hover, opts)
    vim.keymap.set('n', '<C-k>', vim.lsp.buf.signature_help, opts)
    vim.keymap.set('n', '<leader>ca', vim.lsp.buf.code_action, opts)
    vim.keymap.set('n', '<leader>rn', vim.lsp.buf.rename, opts)
    vim.keymap.set('n', '<leader>nd', vim.diagnostic.goto_next, opts)
    vim.keymap.set('n', '<leader>pd', vim.diagnostic.goto_prev, opts)
    vim.keymap.set('n', '<leader>d', vim.diagnostic.open_float, opts)
    vim.keymap.set('n', '<leader>q', vim.diagnostic.setloclist, opts)
  end,
})

-- LSP Info command
vim.api.nvim_create_user_command('LspInfo', function()
  local clients = vim.lsp.get_clients({ bufnr = 0 })
  if #clients == 0 then
    print("No LSP clients attached to current buffer")
  else
    for _, client in ipairs(clients) do
      print("LSP: " .. client.name .. " (ID: " .. client.id .. ")")
    end
  end
end, { desc = 'Show LSP client info' })
