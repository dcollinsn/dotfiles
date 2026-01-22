-- General Neovim options (ported from .vimrc)

local opt = vim.opt
local g = vim.g

-- Encoding and file format
-- Note: Neovim always uses UTF-8 internally, so termencoding is not needed
opt.encoding = "utf-8"
opt.fileencoding = "utf-8"
opt.fileformats = { "unix", "mac", "dos" }

-- File handling
opt.autowrite = true
opt.autoread = true
opt.backup = false
opt.writebackup = false
opt.swapfile = false

-- Persistent undo
opt.undofile = true
opt.undolevels = 5000
opt.undodir = vim.fn.expand("~/.config/nvim/undo")

-- Create undo directory if it doesn't exist
vim.fn.mkdir(vim.fn.expand("~/.config/nvim/undo"), "p")

-- Display settings
opt.number = true
opt.relativenumber = false
opt.cursorline = true
opt.scrolloff = 2
opt.sidescrolloff = 8
opt.wrap = true
opt.linebreak = true
opt.showmode = false
opt.showcmd = true
opt.laststatus = 2
opt.signcolumn = "yes"
opt.title = true

-- Search settings
opt.hlsearch = true
opt.incsearch = true
opt.ignorecase = true
opt.smartcase = true
opt.grepprg = "ag --vimgrep $*"
opt.grepformat = "%f:%l:%c:%m"

-- Tab and indentation
opt.tabstop = 8
opt.softtabstop = 4
opt.shiftwidth = 4
opt.expandtab = true
opt.smartindent = true
opt.autoindent = true
opt.shiftround = true
opt.smarttab = true

-- Whitespace characters
opt.list = true
opt.listchars = {
    tab = "››",
    trail = "·",
    nbsp = "~",
}

-- Completion settings
opt.completeopt = { "menu", "menuone", "noselect" }
opt.wildmode = { "list:longest", "full" }
opt.infercase = true
opt.pumheight = 10

-- Window splitting
opt.splitbelow = true
opt.splitright = true

-- Backspace behavior
opt.backspace = { "indent", "eol", "start" }

-- Timeouts
opt.timeout = true
opt.timeoutlen = 300
opt.ttimeoutlen = 300
opt.updatetime = 250

-- Visual mode
opt.virtualedit = "block"

-- Matching pairs
opt.matchpairs:append("<:>")

-- Folding
opt.foldmethod = "expr"
opt.foldexpr = "nvim_treesitter#foldexpr()"
opt.foldlevelstart = 99
opt.foldenable = false

-- Disable netrw in favor of nvim-tree
g.loaded_netrw = 1
g.loaded_netrwPlugin = 1

-- Format options
opt.formatoptions:remove({ "c", "r", "o" })

-- Python provider (adjust path as needed)
g.python3_host_prog = vim.fn.exepath("python3")

-- Disable built-in plugins we don't need
g.loaded_gzip = 1
g.loaded_zip = 1
g.loaded_zipPlugin = 1
g.loaded_tar = 1
g.loaded_tarPlugin = 1
g.loaded_getscript = 1
g.loaded_getscriptPlugin = 1
g.loaded_vimball = 1
g.loaded_vimballPlugin = 1
g.loaded_2html_plugin = 1
g.loaded_matchit = 1
g.loaded_matchparen = 1
g.loaded_logiPat = 1
g.loaded_rrhelper = 1

-- Fix colors for 256 color terminal
opt.termguicolors = true
opt.background = "dark"
