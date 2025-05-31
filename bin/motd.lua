-- moto of the day
local args = {...}
local shell = table.remove(args,1)
local fs = kernel.filesystem
local localVars = shell.getLocalVars()
if not localVars.data or localVars.lastMOTDEnv ~= shell.getenv("MOTD") then
    -- read the MOTD path in shell env (if not set it up)
    local MOTD = "/bin/.data/motd.lua"
    if shell.getenv("MOTD") then
        MOTD = shell.getenv("MOTD")
    else
        shell.setenv("MOTD",MOTD)
    end
    localVars.lastMOTDEnv = MOTD
    -- dofile motd
    local data,err = dofile(MOTD)
    if not data and err then
        error("failed to load motd data")
    end
    localVars.data = data
end
local function Pmotd(motd)
    if type(motd) == "string" then
        return motd
    elseif type(motd) == "function" then
        return motd(shell)
    else
        return tostring(motd)
    end
end
-- i guess args allows selecting the motd
if args[1] and tonumber(args[1]) then
    local index = tonumber(args[1])
    if index > #localVars.data then
        return Pmotd(localVars.data[#localVars.data])
    elseif index < 1 then
        return Pmotd(localVars.data[1])
    else
        return Pmotd(localVars.data[index])
    end
end
-- select one at random
return Pmotd(localVars.data[math.random(1,#localVars.data)])