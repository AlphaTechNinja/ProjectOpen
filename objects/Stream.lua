local classes = require("classes")
local Stream = classes.create("Stream")
function Stream:constructor(data)
    -- inital data
    checkArg(1,data,{"string","nil"})
    local initdata = {}
    if type(data) == "string" and #data > 0 then
        table.insert(initdata,data)
    end
    return setmetatable({__data=initdata},self)
end
function Stream:__tostring()
    return "Stream: 0x"..string.match(tostring(self.__data), "0x%x+")
end
local function sanitizedConcat(tab,sep)
    -- first filter
    local filtered = {}
    for i=1,#tab do
        if tab[i] ~= nil then
            table.insert(filtered,tab[i])
        end
        if type(tab[i]) == "table" then
            error("found a booger "..debug.traceback("",3),2)
        end
    end
    return table.concat(filtered,sep)
end
function Stream:write(data)
    checkArg(1,data,"string")
    if self.__pipewrite then
        self.__pipewrite:write(data)
        return
    end
    table.insert(self.__data,data)
end
function Stream:read(len)
    if self.__piperead then
        return self.__piperead:read(len)
    end
    len = len or 1
    if len == math.huge then
        local temp = sanitizedConcat(self.__data, "")
        self.__data = {}
        return temp
    end

    local data = {}
    local i = 1

    while i <= #self.__data and len > 0 do
        local entry = self.__data[i]
        if not entry then break end

        if #entry > len then
            -- split chunk
            table.insert(data, entry:sub(1, len))
            self.__data[i] = entry:sub(len + 1)
            len = 0
        else
            -- take whole entry
            table.insert(data, entry)
            len = len - #entry
            table.remove(self.__data, i)
            -- do not increment i here since we removed this index
            i = i - 1
        end
        i = i + 1
    end

    return sanitizedConcat(data, "")
end
function Stream:flush()
    return self:read(math.huge)
end
-- piping
function Stream:pipe(pipe,mode)
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
return Stream