-- Utility functions ported from .vimrc
return {
    -- Trim trailing whitespace
    trim_trailing_whitespace = function()
        local cursor_pos = vim.api.nvim_win_get_cursor(0)
        vim.cmd([[%s/\s\+$//e]])
        vim.api.nvim_win_set_cursor(0, cursor_pos)
    end,

    -- Ensure parent directory exists before writing
    ensure_dir_exists = function()
        local dir = vim.fn.expand("%:p:h")
        if vim.fn.isdirectory(dir) == 0 then
            vim.fn.mkdir(dir, "p")
        end
    end,

    -- Toggle help in new tab
    help_in_new_tab = function()
        if vim.bo.buftype == "help" then
            vim.cmd("wincmd T")
        end
    end,

    -- Word count function
    word_count = function()
        local lines = table.concat(vim.api.nvim_buf_get_lines(0, 0, -1, false), " ")
        local count = 0
        for _ in string.gmatch(lines, "%S+") do
            count = count + 1
        end
        return count
    end,

    -- Diff changes against original file
    diff_changes = function()
        vim.cmd("diffthis")
        vim.cmd("vnew")
        vim.cmd("r #")
        vim.cmd("1d_")
        vim.cmd("diffthis")
        vim.cmd([[
      nmap <silent><buffer> zd :diffoff<CR>:q!<CR>:set nodiff<CR>
    ]])
    end,

    -- Set tab spacing
    set_tab_spacing = function(size)
        vim.opt.tabstop = size
        vim.opt.shiftwidth = size
        vim.opt.softtabstop = size
    end,

    -- Toggle comment (language-aware)
    toggle_comment = function()
        local comment_chars = {
            python = "#",
            sh = "#",
            bash = "#",
            zsh = "#",
            vim = '"',
            lua = "--",
            javascript = "//",
            typescript = "//",
            c = "//",
            cpp = "//",
            go = "//",
            rust = "//",
            ruby = "#",
            php = "//",
            css = "/*",
            html = "<!--",
        }

        local ft = vim.bo.filetype
        local cmt = comment_chars[ft] or "#"

        local line = vim.api.nvim_get_current_line()
        local line_num = vim.api.nvim_win_get_cursor(0)[1]

        if line:match("^%s*" .. vim.pesc(cmt)) then
            -- Remove comment
            local new_line = line:gsub("^(%s*)" .. vim.pesc(cmt) .. "%s?", "%1")
            vim.api.nvim_buf_set_lines(0, line_num - 1, line_num, false, { new_line })
        else
            -- Add comment
            local new_line = line:gsub("^(%s*)", "%1" .. cmt .. " ")
            vim.api.nvim_buf_set_lines(0, line_num - 1, line_num, false, { new_line })
        end
    end,

    -- Highlight search match briefly
    blink_search_match = function(blinktime)
        local pattern = vim.fn.getreg("/")
        local match_id = vim.fn.matchadd("IncSearch", [[\c\%#]] .. pattern, 101)
        vim.cmd("redraw")
        vim.defer_fn(function()
            vim.fn.matchdelete(match_id)
        end, blinktime)
    end,
}
