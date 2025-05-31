local classes = require("classes")
local Stream = classes.create("SeekableStream")
Stream.__pos = 1
function Stream:constructor(data)
    -- inital data
    checkArg(1,data,{"string","nil"})
    return setmetatable({__data=data or ""})
end
function Stream:__tostring()
    return self.__data
end
function Stream:write(data)
    checkArg(1,data,"string")
    if self.__pipewrite then
        self.__pipewrite:write(data)
        return
    end
    if self.__pos == #self.__data + 1 then
        self.__data = self.__data..data
        self.__pos = #self.__data
    else
        -- split the data
        local leftside = self.__data:sub(1,self.__pos)
        local rightside = self.__data:sub(self.__pos + 1,-1)
        self.__data = leftside..data..rightside
        self.__pos = self.__pos + #data
    end
end
function Stream:read(len,consume)
    if self.__piperead then
        return self.__piperead:read(len)
    end

    len = len or 1
    if self.__pos > #self.__data then
        return ""
    end

    if len == math.huge or (self.__pos + len - 1) > #self.__data then
        len = #self.__data - self.__pos + 1
    end

    local data = self.__data:sub(self.__pos, self.__pos + len - 1)
    
    -- remove read chunk
    if consume ~= false then
        local left = self.__data:sub(1, self.__pos - 1)
        local right = self.__data:sub(self.__pos + len)
        self.__data = left .. right
        self.__pos = 1 -- reset position since data shifted
    end
    return data
end

function Stream:flush()
    return self:read(math.huge)
end
-- piping
function Stream:pipe(pipe,mode)
    checkArg(1,pipe,"table")
    if mode == "r" then
        assert(pipe.read,"Target pipe has no read function")
        self.__piperead = pipe
    elseif mode == "w" then
        assert(pipe.write,"Target pipe has no write function")
        self.__pipewrite = pipe
    elseif mode == "rw" then
        assert(pipe.read,"Target pipe has no read function")
        assert(pipe.write,"Target pipe has no write function")
        self.__piperead = pipe
        self.__pipewrite = pipe
    else
        errorf("Invalid piping mode '%s'",mode,2)
    end
end
function Stream:seek(whence,pos)
    whence = whence or "start"
    if whence == "start" then
        self.__pos = pos
    elseif whence == "cur" then
        self.__pos = self.__pos + pos
    elseif whence == "end" then
        self.__pos = #self.__data - pos
    end
end
return Stream