local M = {}

local default_config = {
    debugmaster = false,
}

local plugin_config = vim.deepcopy(default_config)

M.setup = function(user_config)
    plugin_config = vim.tbl_deep_extend('force', vim.deepcopy(default_config), user_config or {})

    if plugin_config.debugmaster then
        local dm = require("debugmaster")
        M.term = require("terminal.debugmaster")

        dm.keys.get("x").key = "dp"

        dm.keys.add({
            key = "s",
            action = M.choose_target,
            desc = "",
        })

        dm.keys.add({
            key = "C",
            action = M.term.open_terminal,
            desc = "",
        })

        dm.keys.add({
            key = "p",
            action = M.build_and_debug,
            desc = "",
        })

        dm.keys.add({
            key = "P",
            action = M.debug,
            desc = "",
        })

        dm.keys.add({
            key = "x",
            action = M.build_and_run,
            desc = "",
        })

        dm.keys.add({
            key = "X",
            action = M.run,
            desc = "",
        })
    else
        M.term = require("terminal.basic")
    end
end

local co = coroutine
local config_dir = nil
local config = nil
local target = nil

local function co_select(items, opts)
    local thread = co.running()
    vim.ui.select(items, opts, function(choice) co.resume(thread, choice) end)

    local choice = co.yield(thread)
    return choice
end

local function get_config_directory()
    if config_dir == nil then
        config_dir = vim.fs.root(vim.fn.getcwd(), ".brd.lua")
        if config_dir == nil then
            local create_file = co_select({ "yes", "no" },
                { prompt = "Create .brd.lua file at " .. vim.fn.getcwd() .. "?" })
            if create_file == nil or create_file == "no" then
                return
            end
            vim.cmd.edit(".brd.lua")
            vim.api.nvim_buf_set_lines(0, 0, 0, true, { "return {", "}" })
            vim.api.nvim_win_set_cursor(0, { 1, 0 })
            vim.cmd.write()
        end
    end
end

local load_config = function()
    get_config_directory()
    config = dofile(config_dir .. "/.brd.lua")
end

local function choose_target()
    load_config()
    local targets = {}
    for k, _ in pairs(config) do
        table.insert(targets, k)
    end

    local new_target = co_select(targets, {})
    if new_target ~= nil then
        target = new_target
    end
end

-- TODO: refactor
local function load_target()
    if target == nil then
        choose_target()
    end
end

M.get_dir = function()
    return config_dir .. "/" .. config[target]["dir"]
end

local function get_debug_configuration()
    return config[target]["debug"]["configuration"]
end

M.get_debug_executable = function()
    return M.get_dir() .. "/" .. config[target]["debug"]["executable"]
end

M.dap_configurations = {
}

-- what = "b", "r", "br"
local function br(what)
    load_target()
    if target == nil then
        print("Target is not set. Aborting")
        return
    end
    local exec_string = "brd " .. what .. " " .. target
    if M.term.is_buf_terminal() then
        exec_string = "\03" .. exec_string
    end
    M.term.open_terminal()
    vim.fn.chansend(M.term.term_channel, { exec_string, "" })
end

local function debug_impl()
    require("dap").terminate()
    require("dap").run(M.dap_configurations[get_debug_configuration()], {new = true})
end

local function debug()
    load_target()
    if target == nil then
        print("Target is not set. Aborting")
        return
    end
    debug_impl()
end

local function build_and_debug()
    load_target()
    if target == nil then
        print("Target is not set. Aborting")
        return
    end
    local exec_string = "brd b " .. target
    if M.term.is_buf_terminal() then
        exec_string = "\03" .. exec_string
    end
    M.term.open_terminal()
    local bad_group = vim.api.nvim_create_augroup("bad_group", {})
    vim.api.nvim_create_autocmd({ 'TermRequest' }, {
        callback = function(ev)
            vim.api.nvim_clear_autocmds({ group = bad_group })
            if string.sub(ev.data.sequence, 1, 8) == '\x1b]133;D;' then
                if string.sub(ev.data.sequence, 9) == "0" then
                    vim.schedule(M.term.close_terminal)
                    debug_impl()
                end
            end
        end,
        group = bad_group
    })
    vim.fn.chansend(M.term.term_channel, { exec_string, "" })
end

local function run_co(f, ...)
    co.resume(co.create(f), ...)
end


M.build = function()
    run_co(br, "b")
end

M.build_and_run = function()
    run_co(br, "br")
end

M.run = function()
    run_co(br, "r")
end

M.build_and_debug = function()
    run_co(build_and_debug)
end

M.debug = function()
    run_co(debug)
end

M.choose_target = function()
    run_co(choose_target)
end

local bad_cmake_targets = { "^following are some of the valid targets for this Makefile:$",
    "^all %(the default if no target is provided%)$", "^clean$", "^depend$",
    "^edit_cache$", "^rebuild_cache$", ".*%.i$", ".*%.o$", ".*%.s$" }

local cmake_target_template = [[
    $TARGET = {
        dir = "$DIR",
        build = "cmake --build . --target $TARGET",
        run = "./$TARGET",
        debug = {
            configuration = "cpp",
            executable = "$TARGET"
        }
    },

]]

vim.api.nvim_create_user_command("BrdCmake",
    function(opts)
        local build_directory_path = opts["fargs"][1]
        local obj = vim.system({ "cmake", "--build", build_directory_path, "--target", "help" }, { text = true }):wait()
        if obj["code"] ~= 0 then
            print("Failed with exit code " .. obj["code"])
        end
        local targets = obj["stdout"]
        targets = vim.split(targets, "\n")
        table.remove(targets)
        targets = vim.tbl_map(function(value) return string.sub(value, 5) end, targets)
        targets = vim.tbl_filter(
            function(value)
                for _, v in ipairs(bad_cmake_targets) do
                    if string.find(value, v) ~= nil then
                        return false
                    end
                end
                return true
            end, targets)
        local lines_to_insert = ""
        for _, v in ipairs(targets) do
            lines_to_insert = lines_to_insert ..
                string.gsub(string.gsub(cmake_target_template, "$TARGET", v), "$DIR", build_directory_path)
        end
        lines_to_insert = vim.split(lines_to_insert, '\n')
        table.remove(lines_to_insert)
        vim.api.nvim_buf_set_lines(0, 1, 1, true, lines_to_insert)
    end, { nargs = 1 })


vim.api.nvim_create_user_command("BrdConfig",
    function(opts)
        get_config_directory()
        vim.cmd.edit(config_dir .. "/.brd.lua")
    end, { nargs = 0 })


return M
