local M = {}

local buf = -1
local win = -1
local group = vim.api.nvim_create_augroup("code-runner", {}) -- make local
M.term_channel = nil

M.is_buf_terminal = function()
    return vim.api.nvim_buf_is_valid(buf) and vim.bo[buf].buftype == "terminal"
end

local function create_floating_window()
    local width = math.floor(vim.o.columns * 0.95)
    local height = math.floor(vim.o.lines * 0.95)

    local col = math.floor((vim.o.columns - width) / 2)
    local row = math.floor((vim.o.lines - height) / 2)

    if not M.is_buf_terminal() then
        buf = vim.api.nvim_create_buf(false, true)
    end

    local win_config = {
        relative = "editor",
        width = width,
        height = height,
        col = col,
        row = row,
        style = "minimal",
        border = "single",
    }

    win = vim.api.nvim_open_win(buf, true, win_config)
end

M.close_terminal = function()
    if vim.api.nvim_win_is_valid(win) then
        vim.api.nvim_win_hide(win)
    end
end

M.open_terminal = function()
    if not vim.api.nvim_win_is_valid(win) then
        create_floating_window()

        if not M.is_buf_terminal() then
            vim.cmd.terminal()
            vim.bo[buf].buflisted = false
            vim.keymap.set("n", "q", M.close_terminal, { buffer = buf })
            M.term_channel = vim.bo.channel
        end

        vim.api.nvim_create_autocmd("BufEnter", {
            callback = function()
                if buf == vim.api.nvim_get_current_buf() then
                    return
                end
                print("You can't change this buffer.")
                vim.api.nvim_win_set_buf(win, buf)
            end,
            group = group
        })

        vim.api.nvim_create_autocmd("WinClosed", {
            callback = function(ev)
                if win ~= tonumber(ev["match"]) then
                    return
                end
                vim.api.nvim_clear_autocmds({ group = group })
            end,
            group = group
        })
    end
end

M.toggle_terminal = function()
    if not vim.api.nvim_win_is_valid(win) then
        M.open_terminal()
    else
        M.close_terminal()
    end
end

return M
