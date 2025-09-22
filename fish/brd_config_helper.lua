# brc_helper target field

local function find_config()
    local cd_to = "cd ./"
    while true do
        local cur = io.popen(cd_to .. "; find . -maxdepth 1 -name \".brd.lua\"")
        local pwd = io.popen(cd_to .. ";pwd")
        if cur:lines()() ~= nil then
            return pwd:lines()()
        end
        if pwd:lines()() == "/" then
            print("Couldn't find the .brd_config.lua file in any of the parent directories.")
            return nil
        end
        cd_to = cd_to .. "../"
    end
end

local directory = find_config()

local brc = dofile(directory .. "/.brd.lua")

if brc[arg[1]] and brc[arg[1]][arg[2]] then
    if arg[2] == "dir" then
        print(directory .. "/" .. brc[arg[1]][arg[2]])
    else
        print(brc[arg[1]][arg[2]])
    end
else
    -- os.exit(1)
end
