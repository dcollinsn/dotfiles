-- Autocommands (ported from .vimrc, excluding Perl-specific ones)

local augroup = vim.api.nvim_create_augroup
local autocmd = vim.api.nvim_create_autocmd

-- Restore cursor position when opening files
autocmd("BufReadPost", {
  group = augroup("RestoreCursor", { clear = true }),
  callback = function()
    local mark = vim.api.nvim_buf_get_mark(0, '"')
    local lcount = vim.api.nvim_buf_line_count(0)
    if mark[1] > 0 and mark[1] <= lcount then
      pcall(vim.api.nvim_win_set_cursor, 0, mark)
    end
  end,
})

-- Auto-create parent directories when writing files
autocmd("BufWritePre", {
  group = augroup("AutoMkdir", { clear = true }),
  callback = function(event)
    local file = vim.loop.fs_realpath(event.match) or event.match
    vim.fn.mkdir(vim.fn.fnamemodify(file, ":p:h"), "p")
  end,
})

-- Highlight yanked text
autocmd("TextYankPost", {
  group = augroup("HighlightYank", { clear = true }),
  callback = function()
    vim.highlight.on_yank({ higroup = "IncSearch", timeout = 300 })
  end,
})

-- Show invisible characters, except in certain files
autocmd("BufEnter", {
  group = augroup("VisibleNaughtiness", { clear = true }),
  callback = function()
    local ft = vim.bo.filetype
    local modifiable = vim.bo.modifiable
    if ft == "text" or not modifiable then
      vim.opt_local.list = false
    else
      vim.opt_local.list = true
    end
  end,
})

-- Check if file changed outside of vim
autocmd({ "FocusGained", "TermClose", "TermLeave" }, {
  group = augroup("Checktime", { clear = true }),
  command = "checktime",
})

-- Resize splits when window is resized
autocmd("VimResized", {
  group = augroup("ResizeSplits", { clear = true }),
  callback = function()
    vim.cmd("tabdo wincmd =")
  end,
})

-- Close some filetypes with 'q'
autocmd("FileType", {
  group = augroup("CloseWithQ", { clear = true }),
  pattern = {
    "qf",
    "help",
    "man",
    "notify",
    "lspinfo",
    "spectre_panel",
    "startuptime",
    "tsplayground",
    "PlenaryTestPopup",
  },
  callback = function(event)
    vim.bo[event.buf].buflisted = false
    vim.keymap.set("n", "q", "<cmd>close<cr>", { buffer = event.buf, silent = true })
  end,
})

-- Auto-enable syntax for patch files
autocmd({ "BufEnter", "BufLeave" }, {
  group = augroup("PatchHighlight", { clear = true }),
  pattern = { "*.patch", "*.diff" },
  callback = function(event)
    if event.event == "BufEnter" then
      vim.cmd("syntax enable")
    end
  end,
})

-- TODO file syntax highlighting
autocmd({ "BufEnter", "BufLeave" }, {
  group = augroup("TODOHighlight", { clear = true }),
  pattern = { "*.todo", "todo", "ToDo", "TODO" },
  callback = function(event)
    if event.event == "BufEnter" then
      vim.cmd("syntax enable")
    end
  end,
})

-- Python-specific settings
autocmd("FileType", {
  group = augroup("PythonSettings", { clear = true }),
  pattern = "python",
  callback = function()
    vim.opt_local.textwidth = 99
    vim.opt_local.formatoptions = "cqtrol"
    vim.opt_local.comments = "b:#"
  end,
})

-- Git commit message settings
autocmd("FileType", {
  group = augroup("GitSettings", { clear = true }),
  pattern = "gitcommit",
  callback = function()
    vim.opt_local.textwidth = 68
    vim.opt_local.formatoptions = vim.opt_local.formatoptions + "twal"
  end,
})

-- Vim file settings
autocmd("FileType", {
  group = augroup("VimSettings", { clear = true }),
  pattern = "vim",
  callback = function()
    vim.opt_local.textwidth = 80
    vim.opt_local.formatoptions:remove({ "r", "o" })
  end,
})

-- Markdown settings
autocmd("FileType", {
  group = augroup("MarkdownSettings", { clear = true }),
  pattern = "markdown",
  callback = function()
    vim.opt_local.textwidth = 80
  end,
})

-- SCSS settings
autocmd("FileType", {
  group = augroup("SCSSSettings", { clear = true }),
  pattern = "scss",
  callback = function()
    vim.opt_local.shiftwidth = 2
    vim.opt_local.softtabstop = 2
  end,
})

-- PHP settings
autocmd("FileType", {
  group = augroup("PHPSettings", { clear = true }),
  pattern = "php",
  callback = function()
    vim.opt_local.expandtab = false
  end,
})

-- Arcanist file detection
autocmd({ "BufNewFile", "BufRead" }, {
  group = augroup("ArcanistFiles", { clear = true }),
  pattern = { ".arcconfig", ".arclint", ".arcrc", ".arcunit" },
  callback = function()
    vim.bo.filetype = "json"
  end,
})

autocmd({ "BufNewFile", "BufRead" }, {
  group = augroup("ArcanistCommit", { clear = true }),
  pattern = { "new-commit", "differential-update-comments" },
  callback = function()
    vim.bo.filetype = "markdown"
    vim.opt_local.textwidth = 72
    vim.opt_local.formatoptions:append({ "t", "l" })
  end,
})

-- Don't auto-comment on new line
autocmd("FileType", {
  group = augroup("DisableAutoComment", { clear = true }),
  pattern = "*",
  callback = function()
    vim.opt_local.formatoptions:remove({ "c", "r", "o" })
  end,
})

-- Update diagnostics in insert mode
autocmd("InsertLeave", {
  group = augroup("LspDiagnostics", { clear = true }),
  callback = function()
    vim.diagnostic.show()
  end,
})

-- Wrap and spell for text-like documents
autocmd("FileType", {
  group = augroup("WrapSpell", { clear = true }),
  pattern = { "gitcommit", "markdown", "text" },
  callback = function()
    vim.opt_local.wrap = true
    vim.opt_local.spell = true
  end,
})
