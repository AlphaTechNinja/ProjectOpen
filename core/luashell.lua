-- runs Lua code instead of terminal commands
-- built off of simple shell
local io = require("io")
local term = require("terminal")
local fs = require("filesystem")
local Stream = require("Stream")
local shell = require("simpleshell")
local _env = shell.getEnv()
-- executor enviroment
-- command wrapper
local shellW = setmetatable({},{__index = function (t, k)
    local name,err = shell.resolveProgramName(k)
    if not name then
        return nil
    end
    -- return an executer
    return function (...)
        return shell.run(k.." "..table.concat({...}," "))
    end
end})
-- envVars
local envVars = setmetatable({},{__index = function (t, k)
    return _env[k]
end,__newindex = function (t,k,v)
    _env[k] = v
end,__pairs = function (t)
    return pairs(_env)
end})
-- main env
local env = {
    exe = shellW,
    env = envVars,
    fs = fs,
    io = io,
    term = term,

}
setmetatable(env,{__index = _G})
local function execute(str)
    local ok,func = pcall(load,str,"=command",nil,env)
    if not ok and func then
        io.stderr:write("Failed to load code (reason):"..func)
    end
    -- attempt run
    local res = {pcall(func)}
    if not res[1] and res[2] then
        io.stderr:write("Failed to execute code (reason):"..res[2].."\n")
        return
    end
    -- print result to terminal
    if #res > 1 then
        io.stdout:write(table.concat(res," ",2).."\n")
    end
end
-- new prompter
function shell.prompt()
    io.stdout:write(fs.simplify(_env.CWD).."/@".._env.USER..">")
    local command = term.read()
    execute(command)
end
-- used for security
local canGet = true
function shell.getEnv()
    shell.getEnv = nil
    if not canGet then return end
    canGet = false
    return _env
end
return shell