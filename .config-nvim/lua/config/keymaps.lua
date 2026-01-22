-- Keymaps (ported from .vimrc, excluding Perl-specific ones)

local keymap = vim.keymap.set
local opts = { noremap = true, silent = true }

-- Leader keys are set in init.lua

-- Better window navigation
keymap("n", "<C-h>", "<C-w>h", opts)
keymap("n", "<C-j>", "<C-w>j", opts)
keymap("n", "<C-k>", "<C-w>k", opts)
keymap("n", "<C-l>", "<C-w>l", opts)

-- Quick access to Ex commands
keymap("n", ";", ":", { noremap = true })
keymap("v", ";", ":Blockwise ", { noremap = true })

-- Better visual mode
-- Swap v and <C-v> for visual block mode being more useful
keymap("n", "v", "<C-v>", opts)
keymap("n", "<C-v>", "v", opts)
keymap("v", "v", "<C-v>", opts)
keymap("v", "<C-v>", "v", opts)

-- Keep selection when indenting in visual mode
keymap("v", "<", "<gv", opts)
keymap("v", ">", ">gv", opts)

-- Make vaa select entire file
keymap("v", "aa", "VGo1G", opts)

-- Delete in visual mode with backspace
keymap("v", "<BS>", "x", opts)

-- Use space to jump down a page
keymap("n", "<Space>", "<PageDown>", opts)
keymap("v", "<Space>", "<PageDown>", opts)

-- Clear search highlighting
keymap("n", "<BS>", ":nohlsearch<CR>", opts)

-- Remove trailing whitespace
keymap("n", "<BS><BS>", function()
  local cursor_pos = vim.api.nvim_win_get_cursor(0)
  vim.cmd([[%s/\s\+$//e]])
  vim.api.nvim_win_set_cursor(0, cursor_pos)
end, opts)

-- Toggle syntax highlighting
keymap("n", ";y", function()
  if vim.g.syntax_on then
    vim.cmd("syntax off")
    vim.g.syntax_on = false
  else
    vim.cmd("syntax on")
    vim.g.syntax_on = true
  end
end, opts)

-- Buffer navigation with up/down arrows
keymap("n", "<Down>", ":next<CR>", opts)
keymap("n", "<Up>", ":prev<CR>", opts)

-- Better undo/redo
keymap("n", "U", "<C-r>", opts)

-- Extend previous search
keymap("n", "//", "/<C-R>/", { noremap = true })
keymap("n", "///", "/<C-R>/\\|", { noremap = true })

-- Make * respect smartcase
keymap("n", "*", function()
  local word = vim.fn.expand("<cword>")
  vim.fn.setreg("/", "\\<" .. word .. "\\>")
  vim.cmd("normal! n")
end, opts)

-- Edit config file
keymap("n", ";v", ":e ~/.config/nvim/init.lua<CR>", opts)

-- Nuke entire buffer
keymap("n", "XX", "1GdG", opts)

-- Replace buffer with alternate file
keymap("n", "RR", "XX:0r#<CR><C-G>", opts)

-- Insert cut marks
keymap("n", "--", "A<CR><CR><CR><ESC>k6i-----cut-----<ESC><CR>", opts)

-- Indenting in normal mode
keymap("n", ">>", function()
  vim.opt.smartindent = false
  vim.cmd("normal! >>")
  vim.opt.smartindent = true
end, opts)

-- Tab spacing commands (T + shifted number)
local function set_tab_spacing(size)
  vim.opt.tabstop = size
  vim.opt.shiftwidth = size
  vim.opt.softtabstop = size
end

keymap("n", "T!", function() set_tab_spacing(1) end, opts)
keymap("n", "T@", function() set_tab_spacing(2) end, opts)
keymap("n", "T#", function() set_tab_spacing(3) end, opts)
keymap("n", "T$", function() set_tab_spacing(4) end, opts)
keymap("n", "T%", function() set_tab_spacing(5) end, opts)
keymap("n", "T^", function() set_tab_spacing(6) end, opts)
keymap("n", "T&", function() set_tab_spacing(7) end, opts)
keymap("n", "T*", function() set_tab_spacing(8) end, opts)
keymap("n", "T(", function() set_tab_spacing(9) end, opts)

-- Convert to/from spaces/tabs
keymap("n", "TS", function()
  vim.opt.expandtab = true
  vim.cmd("retab!")
end, opts)

keymap("n", "TT", function()
  vim.opt.expandtab = false
  vim.cmd("retab!")
end, opts)

-- Toggle cursor line highlighting
keymap("n", ";R", ":set cursorline!<CR>", opts)

-- Better j/k navigation on wrapped lines
keymap("n", "j", "gj", opts)
keymap("n", "k", "gk", opts)

-- Incremental yank
keymap("v", "Y", '<ESC>:let @y = @"<CR>gv"Yy:let @" = @y<CR>', { noremap = true, silent = true })

-- Move to end of line in visual mode
keymap("v", "]", '$"yygv_$', opts)

-- Unique lines in visual mode
keymap("v", "q", function()
  local start_line = vim.fn.line("'<")
  local end_line = vim.fn.line("'>")
  local lines = vim.api.nvim_buf_get_lines(0, start_line - 1, end_line, false)

  local seen = {}
  local unique_lines = {}
  for _, line in ipairs(lines) do
    if not seen[line] then
      table.insert(unique_lines, line)
      seen[line] = true
    end
  end

  vim.api.nvim_buf_set_lines(0, start_line - 1, end_line, false, unique_lines)
end, opts)

-- Diagnostic keymaps
keymap("n", "[d", vim.diagnostic.goto_prev, { desc = "Previous diagnostic" })
keymap("n", "]d", vim.diagnostic.goto_next, { desc = "Next diagnostic" })
keymap("n", "<leader>d", vim.diagnostic.open_float, { desc = "Line diagnostics" })
keymap("n", "<leader>q", vim.diagnostic.setloclist, { desc = "Quickfix diagnostics" })

-- Better search - highlight briefly
keymap("n", "n", function()
  vim.cmd("normal! n")
  vim.fn.matchadd("IncSearch", [[\c\%#]] .. vim.fn.getreg("/"), 101)
  vim.cmd("redraw")
  vim.defer_fn(function()
    vim.fn.clearmatches()
  end, 400)
end, opts)

keymap("n", "N", function()
  vim.cmd("normal! N")
  vim.fn.matchadd("IncSearch", [[\c\%#]] .. vim.fn.getreg("/"), 101)
  vim.cmd("redraw")
  vim.defer_fn(function()
    vim.fn.clearmatches()
  end, 400)
end, opts)

-- Terminal mode keymaps
keymap("t", "<Esc>", "<C-\\><C-n>", opts)
keymap("t", "<C-h>", "<C-\\><C-n><C-w>h", opts)
keymap("t", "<C-j>", "<C-\\><C-n><C-w>j", opts)
keymap("t", "<C-k>", "<C-\\><C-n><C-w>k", opts)
keymap("t", "<C-l>", "<C-\\><C-n><C-w>l", opts)
