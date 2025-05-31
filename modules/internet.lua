-- internet module
local classes = require("classes")
local internet = {}
local InternetHandle = classes.create("InternetHandle")
local TCPSocket = classes.create("TCPSocket")
function InternetHandle:constructor(...)
    if not component.isAvailable("internet") then
        error("no internet card",2)
    end
    -- runs the http function fetch
    local internetCard = component.internet
    local handle = internetCard.request(...)
    if not handle.finishedConnect() then
        return nil -- unsuccessful
    end
    -- make handle
    return setmetatable({__handle = handle,__closed = false},self)
end
function InternetHandle:read(len)
    if self.__closed then
        error("attempted to use a closed internet handle",2)
    end
    if self.__pipe then
        return self.__pipe:read(len)
    end
    return self.__handle.read(len)
end
function InternetHandle:write()
    error("internet handles cannot be written")
end
function InternetHandle:close()
    if self.__closed then
        return
    end
    self.__closed = true
    self.__handle.close()
end
function InternetHandle:pipe(pipe,mode)
    if mode ~= "r" then
        errorf("invalid mode '%s' for interent handle",mode,2)
    end
    self.__pipe = pipe
end
-- special functions
function InternetHandle:readResponse()
    if self.__closed then
        error("attempted to use a closed internet handle",2)
    end
    return self.__handle.response()
end
function InternetHandle:readAll()
    local chunks = {}
    while true do
        local data = self:read(math.huge)
        if not data then break end
        table.insert(chunks, data)
    end
    return table.concat(chunks)
end

-- oh boy sockets
function TCPSocket:constructor(url,port,timeout)
    timeout = timeout or 10
    if not component.isAvailable("internet") then
        error("no internet card",2)
    end
    -- opens a socket
    local internetCard = component.internet
    local handle = internetCard.connect(url,port)
    if not handle.finishedConnect() then
        -- wait for timeout (sockets take a longer time to connect)
        local deadline = computer.uptime() + timeout
        while computer.uptime() <= deadline do
            coroutine.yield()
        end
        if not handle.finishedConnect() then
            return nil
        end
    end
    -- make handle
    return setmetatable({__handle = handle,__closed = false},self)
end
function TCPSocket:read(len)
    if self.__closed then
        error("attempted to read from a closed socket",2)
    end
    if self.__piperead then
        return self.__piperead:read(len)
    end
    return self.__handle.read(len)
end
function TCPSocket:write(data)
    if self.__closed then
        error("attempted to write to a closed socket",2)
    end
    if self.__pipewrite then
        return self.__pipewrite:write(data)
    end
    return self.__handle.write(data)
end
function TCPSocket:close()
    if self.__closed then
        return
    end
    self.__closed = true
    self.__handle.close()
end
function TCPSocket:pipe(pipe,mode)
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
-- TCPSocket special
function TCPSocket:getID()
    if self.__closed then
        error("attempted to fetch a closed socket's ID",2)
    end
    return self.__handle.id()
end
internet.InternetHandle = InternetHandle
internet.TCPSocket = TCPSocket
function internet.request(...)
    return InternetHandle:new(...)
end
function internet.connect(...)
    return TCPSocket:new(...)
end
return internet