local classes = require("classes")
local io = require("io")
local component = require("component")
local Stream = require("Stream")
local gpu = component.gpu
local stream = {}
local line = 1
function stream:read()
    -- not implemented
    return ""
end
function stream:write(data)
    if self.__writepipe then
        self.__writepipe:write(data)
    end
    gpu.set(1,line,data)
    line = line + 1
end
function stream:pipe(pipe,mode)
    if mode == "r" then
        self.__piperead = pipe
    elseif mode == "w" then
        self.__pipewrite = pipe
    elseif mode == "rw" then
        self.__piperead = pipe
        self.__pipewrite = pipe
    else
        errorf("Invalid piping mode '%s'",mode,2)
    end
end
io.stdout = stream
io.stdin = stream
io.stderr = {write = function (_,data)
    gpu.setForeground(0xFF0000)
    io.stdout:write("error:"..data)
    gpu.setForeground(0xFFFFFF)
end}
-- add print
function print(...)
    local args = {...}
    for i = 1,#args do
        args[i] = tostring(args[i])
    end
    io.stdout:write(table.concat(args," ").."\n")
end