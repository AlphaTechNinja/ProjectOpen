local classes = require("classes")
local fs = require("filesystem")
local Stream = require("Stream")
local SeekableStream = require("SeekableStream")
local IOFile = classes.create("IOFile",SeekableStream)
local io = {}
function IOFile:__tostring()
    return string.format("IOFile<%s>", self.__path or "buffer")
end
function IOFile:constructor(path,mode)
    if mode == "rw" then
        -- special case return a seekable stream
        local data = fs.open(path,"r"):readAll()
        return setmetatable({__data = data,__path = path},self)
    elseif mode == "r" then
        return setmetatable({__handle = fs.open(path,"r"),__mode = "r"},self)
    elseif mode  == "w" then
        return setmetatable({__handle = fs.open(path,"w"),__mode = "w"},self)
    end
end
function IOFile:read(len)
    if self.__close or self.__handle.__close then
        error("Attempt to read a closed stream",2)
    end
    if self.__piperead then
        return self.__piperead:read(len)
    end
    if self.__handle then
        assert(self.__mode == "r","Attempt to read from a Write-Only stream")
        return self.__handle:read(len)
    else
        return SeekableStream.read(self,len,false)
    end
end
function IOFile:write(data)
    if self.__close or self.__handle.__close then
        error("Attempt to write to a closed stream",2)
    end
    if self.__pipewrite then
        self.__pipewrite:write(data)
        return
    end
    if self.__handle then
        assert(self.__mode == "w","Attempt to write to a Read-Only stream")
        return self.__handle:write(data)
    else
        return SeekableStream.write(self,data)
    end
end
function IOFile:seek(whence,pos)
    if self.__close or self.__handle.__close then
        error("Attempt to seek a closed stream",2)
    end
    if self.__handle then
        assert(self.__mode == "r","Attempted to seek a Write-Only stream")
        return self.__handle:seek(whence,pos)
    else
        return SeekableStream.seek(self,whence,pos)
    end
end
function IOFile:close()
    if not self.__handle then
        self.__close = true
        return
    end
    self.__handle:close()
end
function IOFile:flush()
    assert(self.__mode ~= "r", "Attempted to flush a Read-Only stream")

    if self.__handle then
        self:close()
        return true
    end

    local ok, err = pcall(function()
        local handle = fs.open(self.__path, "w")
        handle:write(self.__data)
        handle:close()
    end)

    if not ok then return nil, err end
    return true
end
function io.open(path,mode)
    return IOFile:new(path,mode)
end
function io.lines(path)
    local data = fs.open(path,"r"):readAll()
    return data:gmatch("[^\n]+")
end

return io