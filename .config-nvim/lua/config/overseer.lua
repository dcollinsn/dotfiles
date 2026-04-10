local overseer = require("overseer")

overseer.register_template({
    name = "Lint with ESLint Unix",
    desc = "Install unix formatter and run ESLint with quickfix support",
    builder = function()
        return {
            -- Use a single shell command string to chain the installation and linting
            cmd = 'npm install -D eslint-formatter-unix && npx eslint -f unix .',
            components = {
                {
                    "on_output_quickfix",
                    -- The unix formatter uses standard 'file:line:col: message' format
                    errorformat = "%f:%l:%c: %m",
                    -- Automatically open the quickfix window if errors are found
                    open = true,
                    -- Only open if the task results in errors
                    open_on_exit = "failure",
                    -- Sync results with Neovim's diagnostic engine
                    set_diagnostics = true,
                },
                -- This component allows the task to be viewed in the Overseer UI
                "default",
                -- Optional: Remove this if you want to silence the "FAILURE" notification popup
                -- { "on_complete_notify", statuses = { "SUCCESS" } },
            },
        }
    end,
    condition = {
        callback = function()
            -- Only show this task if package.json exists in the current directory
            return vim.fn.filereadable("package.json") == 1
        end,
    },
})

local map = vim.keymap.set

-- Open the menu to select and run a template
map("n", "<leader>or", "<cmd>OverseerRun<cr>", { desc = "Overseer Run" })

-- Toggle the task list window to see running/failed tasks
map("n", "<leader>ot", "<cmd>OverseerToggle<cr>", { desc = "Overseer Toggle" })

-- Quickly re-run the last task (your lint command) without the menu
map("n", "<leader>ol", "<cmd>OverseerRunAction<cr>", { desc = "Overseer Run Last" })
