local classes = require("classes")
local Stream = require("Stream")
local advStream = classes.create("AdvancedStream",Stream)
-- no piping special stream
local function handleReverse(self,data)
    if self.reverse then
        return string.reverse(data)
    else
        return data
    end
end
local function smartWrite(self,data)
    data = handleReverse(self,data)
    if self.index == #self.data then
        self.data = self.data..data
        self.index = #self.data
    else
        -- split left and right
        local left = self.data:sub(1,self.index-1)
        local right = self.data:sub(self.index,-1)
        self.data = left..data..right
    end
end
function advStream:constructor()
    return setmetatable({data="",index=1,reverse=false},self)
end
function advStream:load(data)
    self.data = data
    self.index = 1
end
function advStream:seek(index,ends)
    if ends then
        if index < 0 then
            self.index = #self.data - math.ceil(-index)
        else
            self.index = math.ceil(index)
        end
    else
        self.index = self.index + math.ceil(index)
    end
    self.index = math.min(math.max(self.index,1),#self.data)
end
function advStream:read(len)
    len = len or 1
    local oldIndex = self.index
    self.index = math.min(self.index+len,#self.data)
    return handleReverse(self,self.data:sub(oldIndex,self.index))
end
function advStream:readByte()
    return string.unpack("I1",self:read(1))
end
function advStream:readHalf()
    return string.unpack("I2",self:read(2))
end
function advStream:readWord()
    return string.unpack("I4",self:read(4))
end
function advStream:readLarge()
    return string.unpack("I8",self:read(8))
end
function advStream:readUint(size)
    return string.unpack("I"..size,self:read(size))
end
function advStream:write(...)
    local args = {...}
    if #args>1 then
        for i=1,#args do
            self:write(args[i])
        end
        return
    end
    local primative = args[1]
    if type(primative) == "string" then
        smartWrite(self,primative)
    elseif type(primative) == "number" then
        smartWrite(self,string.pack("n",primative))
    elseif type(primative) == "boolean" then
        smartWrite(self,string.pack("B",primative and 0xff or 0x00))
    end
end
function advStream:readDecode(pat,len)
    return string.unpack(pat,self:read(len))
end
function advStream:writeEncode(pat,...)
    self:write(string.pack(pat,...))
end
function advStream:writeByte(v)
    self:write(string.pack("I1",v))
end
function advStream:writeHalf(v)
    self:write(string.pack("I2",v))
end
function advStream:writeWord(v)
    self:write(string.pack("I4",v))
end
function advStream:writeLarge(v)
    self:write(string.pack("I8",v))
end
function advStream:merge(other)
    if other.data then
        self:write(other.data)
    end
end
function advStream:dump(other)
    if other.write then
        other:write(self.data)
    end
end
-- special finders
function advStream:findSignature(signature,start)
    -- finds that signature
    start = start or 1
    if start < 0 then
        -- start from end
        for i=#self.data+start,1,-1 do
            -- locate it
            if i < #signature then
                return nil
            end
            local chunk = self.data:sub(i-#signature+1,i)
            if chunk == signature then
                return i-#signature+1
            end
        end
        return nil
    else
        for i=1,#self.data do
            if i+#signature > #self.data then
                return nil
            end
            local chunk = self.data:sub(i,i+#signature-1)
            if chunk == signature then
                return i
            end
        end
        return nil
    end
end
-- cool reference object
local Reference = classes.create("StreamReference")
function Reference:constructor(stream,index)
    assert(stream.data and stream.index,"not a valid stream")
    return setmetatable({stream=stream,index=index,reverse=false},self)
end
function Reference:point(other)
    if other == nil or other:isOf(Reference) then
        self.__ptr = other
    end
end
function Reference:move(newIndex)
    self.index = newIndex
end
function Reference:changeStream(stream)
    assert(stream.data and stream.index,"not a valid stream")
    self.stream = stream
end
function Reference:read(len)
    local index = self.index
    if self.__ptr then
        index = self.__ptr.index
    end
    local data = self.stream.data:sub(self.index,index+len-1)
    return handleReverse(data)
end
function Reference:readUp(depth,len)
    -- pointer hell
    if depth == 0 then
        local data = self.stream.data:sub(self.index,self.index+len-1)
        return handleReverse(data)
    elseif depth == 1 then
        return self:read(len)
    elseif depth > 1 then
        if self.__ptr then
            return self.__ptr:readUp(depth-1,len)
        else
            return self:read(len)
        end
    end
end
return {Stream=advStream,Reference=Reference}