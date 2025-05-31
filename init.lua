function run_with_traceback(func, ...)
    local args= {...}
    return xpcall(function() return func(table.unpack(args)) end, function(err)
        return debug.traceback("Error: " .. tostring(err), 2)
    end)
end
local ok,err = run_with_traceback(function ()
-- fresh OS
-- setup component wrapper for OpenOS compatablity
component = component
setmetatable(component,{
    __index = function (t, k)
        return component.proxy(component.list(k)())
    end
})
-- setup inital loading
function loadstring(chunk,name,...)
    return load(chunk,name or "=loadstring",...)
end
local fs = component.proxy(computer.getBootAddress())
function readfile(path)
    local handle,err = fs.open(path,"r")
    if not handle and err then
        return nil,("failed to open file '%s':\n%s"):format(path,err)
    end
    -- read until empty
    local buffer = {}
    repeat
        local data,err = fs.read(handle,math.huge)
        if not data and err then
            return nil,("failed to read '%s':\n%s"):format(path,err)
        end
        table.insert(buffer,data)
    until data == nil
    fs.close(handle)
    return table.concat(buffer,"")
end
-- loadfile
function loadfile(path,...)
    -- attempt read
    local data,err = readfile(path)
    if not data and err then
        return nil,("failed to load file '%s':\n%s"):format(path,err)
    end
    return load(data,"="..path,...)
end
-- dofile
function dofile(path,...)
    local func,err = loadfile(path)
    if not func and err then
        return nil,err
    end
    -- watch for errs
    local result = {pcall(func,...)}
    if not result[1] and result[2] then
        return nil,("failed to do file '%s':\n%s"):format(path,result[2])
    end
    return table.unpack(result,2)
end
kernel = {}
function runkernel(path,...)
    return dofile(path,kernel,...)
end
-- a very much needed core lua function prints a formatted error message
function errorf(message, ...)
    local args = { ... }
    if type(message) ~= "string" then
        error("bad argument #1 to 'errorf' (string expected)", 2)
    end
    local level = table.remove(args)
    if type(level) ~= "number" then
        error("bad argument #" .. (#args + 2) .. " to 'errorf' (number expected for error level)", 2)
    end
    error(string.format(message, table.unpack(args)), level + 1)
end

-- the concept of this OS is to provide higher abstractions
-- so drives exists drivers will be loaded first
-- but we need package's skeleton
-- which in turn requires fs /: (dependancy reccurence sadly)
kernel.component = component
kernel.classes = runkernel("/classes.lua")
kernel.filesystem = runkernel("/filesystem.lua")
kernel.package = runkernel("/package.lua")
kernel.event = require("event") -- needed before these libs load
kernel.poller = require("poll")
-- do run once files  in libs
for _,file in ipairs(kernel.filesystem.list("/libs/")) do
    dofile(kernel.filesystem.combine("/libs/",file))
end
kernel.io = require("io")
-- debug
kernel.term = require("term")
kernel.terminal = require("terminal")
kernel.shell = require("simpleshell")
kernel.os = require("os")
kernel.package.delay(kernel.os,"/full/os.lua")
--kernel.terminal.blinkDisabled()
local function tracebackHandler(err)
    return debug.traceback("Error: " .. tostring(err), 2)
end
-- simple alias for builtins
local shell = kernel.shell
-- for god's sake i automated this
--[[
shell.setalias("echo.lua","echo")
shell.setalias("cat.lua","cat")
shell.setalias("ls.lua","ls")
shell.setalias("cd.lua","cd")
shell.setalias("clear.lua","clear")
shell.setalias("help.lua","help")
shell.setalias("motd.lua","motd")
--]]
local progs = shell.getenv("PROGS")
for _,file in ipairs(kernel.filesystem.list(progs)) do
    local name = file:sub(1,-5)
    shell.setalias(file,name)
end
-- shorter names (and longer names for ls)
shell.setalias("ls.lua","list")
shell.setalias("debug.lua","db")
shell.setalias("echo.lua","ec")
shell.setalias("help.lua","man")
shell.setalias("clear.lua","clr")

kernel.io.stdout:write(kernel.io.popen("motd 1"))
kernel.poller.register(function ()
    local ok, err = xpcall(function() shell.prompt() end, tracebackHandler)
    if not ok then
        kernel.io.stderr:write(err .. "\n")
    end
end,"OS_loop")
while true do
    kernel.poller.poll()
    kernel.event.wait(0.05)
end
end)
error(err,2)