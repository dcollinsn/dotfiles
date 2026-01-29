-- Core editing plugins
return {
    -- Git integration (replaces vim-fugitive and vim-gitgutter)
    {
        "lewis6991/gitsigns.nvim",
        event = { "BufReadPre", "BufNewFile" },
        config = function()
            require("gitsigns").setup({
                signs = {
                    add = { text = "+" },
                    change = { text = "~" },
                    delete = { text = "_" },
                    topdelete = { text = "‾" },
                    changedelete = { text = "~" },
                },
                update_debounce = 250,
                current_line_blame = false,
            })
        end,
    },

    -- Fuzzy finder (replaces Command-T)
    {
        "nvim-telescope/telescope.nvim",
        dependencies = { "nvim-lua/plenary.nvim" },
        cmd = "Telescope",
        keys = {
            { "<C-p>",      "<cmd>Telescope find_files<cr>", desc = "Find Files" },
            { "<leader>t",  "<cmd>Telescope find_files<cr>", desc = "Find Files" },
            { "\\t",        "<cmd>Telescope find_files<cr>", desc = "Find Files" },
            { "<leader>fg", "<cmd>Telescope live_grep<cr>",  desc = "Live Grep" },
            { "<leader>fb", "<cmd>Telescope buffers<cr>",    desc = "Buffers" },
            { "<leader>fh", "<cmd>Telescope help_tags<cr>",  desc = "Help Tags" },
        },
        config = function()
            local telescope = require("telescope")
            local actions = require("telescope.actions")
            local action_state = require("telescope.actions.state")

            -- Custom action to send only selected or current entry
            local send_selected_only = function(prompt_bufnr)
                local picker = action_state.get_current_picker(prompt_bufnr)
                local multi = picker:get_multi_selection()

                if vim.tbl_isempty(multi) then
                    -- No multi-selection, send current entry
                    actions.send_selected_to_qflist(prompt_bufnr)
                else
                    -- Send only the multi-selected entries
                    actions.send_selected_to_qflist(prompt_bufnr)
                end
                actions.open_qflist(prompt_bufnr)
            end

            telescope.setup({
                defaults = {
                    file_ignore_patterns = {
                        ".git/",
                        "venv/",
                        "__pycache__/",
                        "node_modules/",
                        "media/",
                        "static_root/",
                        "apicache%-py3/",
                    },
                    mappings = {
                        i = {
                            ["<C-j>"] = actions.move_selection_next,
                            ["<C-k>"] = actions.move_selection_previous,
                            ["<C-q>"] = send_selected_only,
                            ["<C-S-q>"] = actions.send_to_qflist + actions.open_qflist,
                        },
                    },
                },
            })
        end,
    },
    {
        "nvim-telescope/telescope-frecency.nvim",
        -- install the latest stable version
        version = "*",
        config = function()
            require("telescope").load_extension "frecency"
        end,
    },
    {
        "nvim-telescope/telescope-file-browser.nvim",
        dependencies = { "nvim-telescope/telescope.nvim", "nvim-lua/plenary.nvim" }
    },

    -- Statusline (replaces vim-airline)
    {
        "nvim-lualine/lualine.nvim",
        dependencies = { "nvim-tree/nvim-web-devicons" },
        event = "VeryLazy",
        config = function()
            require("lualine").setup({
                options = {
                    theme = "auto",
                    component_separators = { left = "", right = "" },
                    section_separators = { left = "", right = "" },
                    icons_enabled = true,
                },
                sections = {
                    lualine_a = { "mode" },
                    lualine_b = { "branch", "diff", "diagnostics" },
                    lualine_c = { { "filename", path = 1 } },
                    lualine_x = { "encoding", "fileformat", "filetype" },
                    lualine_y = { "progress" },
                    lualine_z = { "location" },
                },
                tabline = {
                    lualine_a = { { "buffers", show_filename_only = false } },
                    lualine_z = { "tabs" },
                },
            })
        end,
    },

    -- Commenting support
    {
        "numToStr/Comment.nvim",
        event = { "BufReadPre", "BufNewFile" },
        config = function()
            require("Comment").setup({
                toggler = {
                    line = "#",
                },
                opleader = {
                    line = "#",
                },
            })
        end,
    },

    -- CSV support (replaces csv.vim)
    {
        "chrisbra/csv.vim",
        ft = "csv",
    },

    -- Better search highlighting
    {
        "nvim-pack/nvim-spectre",
        dependencies = { "nvim-lua/plenary.nvim" },
        keys = {
            { "<leader>sr", '<cmd>lua require("spectre").open()<cr>', desc = "Search & Replace" },
        },
    },

    -- Improved increment/decrement
    {
        "monaqa/dial.nvim",
        keys = {
            { "<C-a>", mode = { "n", "v" } },
            { "<C-x>", mode = { "n", "v" } },
        },
    },

    -- Auto pairs
    {
        "windwp/nvim-autopairs",
        event = "InsertEnter",
        config = function()
            require("nvim-autopairs").setup({})
        end,
    },

    -- Highlight word under cursor
    {
        "RRethy/vim-illuminate",
        event = { "BufReadPost", "BufNewFile" },
        config = function()
            require("illuminate").configure({
                delay = 200,
                under_cursor = false,
            })
        end,
    },

    -- Indentation guides
    {
        "lukas-reineke/indent-blankline.nvim",
        event = { "BufReadPost", "BufNewFile" },
        main = "ibl",
        config = function()
            require("ibl").setup({
                scope = { enabled = false },
            })
        end,
    },

    -- Better quickfix
    {
        "kevinhwang91/nvim-bqf",
        ft = "qf",
    },

    -- Surround text objects
    {
        "kylechui/nvim-surround",
        event = { "BufReadPre", "BufNewFile" },
        config = function()
            require("nvim-surround").setup({})
        end,
    },

    -- Move visual selections with arrow keys
    {
        "booperlv/nvim-gomove",
        event = { "BufReadPre", "BufNewFile" },
        config = function()
            require("gomove").setup({
                map_defaults = false,
            })

            -- Visual mode arrow key mappings for moving lines/blocks
            vim.keymap.set("v", "<Up>", "<Plug>GoVSMUp", {})
            vim.keymap.set("v", "<Down>", "<Plug>GoVSMDown", {})
            vim.keymap.set("v", "<Left>", "<Plug>GoVSMLeft", {})
            vim.keymap.set("v", "<Right>", "<Plug>GoVSMRight", {})
        end,
    },
}
