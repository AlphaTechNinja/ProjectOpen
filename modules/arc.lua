local classes = require(".classes")
local Adv = require(".AdvancedStream")
local Stream, Reference = Adv.Stream, Adv.Reference
local LibDeflate = require(".LibDeflate")
local bit = bit

-- bit helpers
function bit.sethigh(n,i)
    return bit.bor(n, bit.blshift(1, i))
end
function bit.setlow(n,i)
    return bit.band(n, bit.bnot(bit.blshift(1, i)))
end
function bit.set(n,i,v)
    if v == 1 then v = true end
    if v == 0 then v = false end
    if v then
        return bit.sethigh(n, i)
    else
        return bit.setlow(n, i)
    end
end
function bit.get(n,i)
    local p = bit.blshift(1, i)
    return bit.band(n, p) == p
end

-- crc32 table
local crc32_table = {}
for i = 0, 255 do
    local crc = i
    for _ = 1, 8 do
        if bit.band(crc, 1) == 1 then
            crc = bit.bxor(bit.brshift(crc, 1), 0xEDB88320)
        else
            crc = bit.brshift(crc, 1)
        end
    end
    crc32_table[i] = crc
end

local function makecrc(str)
    local crc = 0xFFFFFFFF
    for i = 1, #str do
        local b = string.byte(str, i)
        local idx = bit.band(bit.bxor(crc, b), 0xFF)
        crc = bit.bxor(crc32_table[idx], bit.brshift(crc, 8))
    end
    return bit.bnot(crc) % 0x100000000
end

local ARC = {}
ARC.MAJOR = 1
ARC.MINOR = 1

-- archive builder
function ARC.archive(data, config)
    config = config or {}
    local ext = config.extension or ""
    local flags = 0

    -- bit 0: crc
    flags = bit.set(flags, 0, not (config.nocrc or false))

    -- extra (flag bit 1)
    local extra
    if config.extra and type(config.extra) == "string" and #config.extra > 0 then
        flags = bit.sethigh(flags, 1)
        extra = config.extra:sub(1, bit.blshift(1, 17) - 1)
    end

    -- extractor (flag bit 2)
    local extract
    if config.extract and type(config.extract) == "string" and #config.extract > 0 then
        flags = bit.sethigh(flags, 2)
        if #config.extract > bit.blshift(1, 17) - 1 then
            error("extractor is too large", 2)
        end
        extract = config.extract
    end

    -- version flag (bit 3)
    flags = bit.set(flags, 3, not config.noversion)

    -- custom flags (bit 7 = more flags)
    local customFlags = {}
    if config.custom and type(config.custom) == "table" and #config.custom > 0 then
        flags = bit.sethigh(flags, 7)
        local perByte = 6 -- store 6 user flags per byte, bit 7 = continuation
        local nbytes = math.ceil(#config.custom / perByte)
        for i = 1, nbytes do
            local byte = 0
            for j = 0, perByte - 1 do
                local idx = (i - 1) * perByte + j + 1
                local val = false
                if idx <= #config.custom then val = not not config.custom[idx] end
                byte = bit.set(byte, j, val)
            end
            -- set bit 7 if more bytes follow
            if i < nbytes then
                byte = bit.sethigh(byte, 7)
            end
            customFlags[#customFlags + 1] = byte
        end
    end

    -- crc
    local crc32
    if not config.nocrc then
        crc32 = makecrc(data)
    end

    -- start writing
    local writer = Stream:new("")
    writer:write("ARC ")
    writer:writeHalf(#ext)
    writer:write(ext)
    writer:writeHalf(config.method or 0)
    writer:writeByte(flags)

    -- version 
    if not config.noversion then
        -- write minor then major
        writer:writeByte(ARC.MINOR)
        writer:writeByte(ARC.MAJOR)
        -- write minimum extraction version
        writer:writeByte(config.MINOR or ARC.MINOR)
        writer:writeByte(config.MAJOR or ARC.MAJOR)
    end

    -- write custom flags bytes
    for i = 1, #customFlags do
        writer:writeByte(customFlags[i])
    end

    -- write crc if included
    if not config.nocrc then
        writer:writeWord(crc32)
    end

    -- write extra
    if extra then
        writer:writeHalf(#extra)
        writer:write(extra)
    end

    -- write extractor
    if extract then
        writer:writeHalf(#extract)
        writer:write(extract)
    end

    -- size handling
    if #data > 0xFFFFFFFF then
        writer:writeWord(0xFFFFFFFF)
        writer:writeLarge(#data) -- actual large size
    else
        writer:writeWord(#data)
    end

    -- write payload
    writer:write(data)

    return writer.data
end

-- unarchive reader
function ARC.unarchive(data)
    local reader = Stream:new(data)
    reader:load(data)
    local size = 0
    local res = {}

    -- magic
    local magic = reader:read(4)
    assert(magic == "ARC ", "Data may be a corrupted ARC or not an ARC at all")
    size = size + 4

    -- extension
    local extlen = reader:readHalf()
    res.extension = reader:read(extlen)
    size = size + extlen + 2

    -- method / flags
    res.method = reader:readHalf()
    size = size + 2
    res.flags = reader:readByte()
    size = size + 1
    local flags = res.flags

    -- version block
    if bit.get(flags, 3) then
        res.version_MINOR = reader:readByte()
        res.version_MAJOR = reader:readByte()
        res.versionMin_MINOR = reader:readByte()
        res.versionMin_MAJOR = reader:readByte()

        -- version check
        if ARC.MAJOR < res.versionMin_MAJOR or (ARC.MAJOR == res.versionMin_MAJOR and ARC.MINOR < res.versionMin_MINOR) then
            error("This ARC is for a later version")
        end

        res.version = ("%d.%d"):format(res.version_MAJOR, res.version_MINOR)
        size = size + 4
    end

    -- extra flags (custom flags) parsing
    if bit.get(flags, 7) then
        res.extraFlags = {}
        local idx = 1
        while true do
            size = size + 1
            local byte = reader:readByte()
            -- extract up to 7 flags
            for b = 0, 6 do
                res.extraFlags[idx] = bit.get(byte, b)
                idx = idx + 1
            end
            -- read until bit 7 is 0
            if not bit.get(byte, 7) then
                break
            end
        end
    end

    -- crc (bit 0 indicates crc present)
    local crc
    if bit.get(flags, 0) then
        crc = reader:readWord()
        size = size + 4
    end
    res.crc32 = crc

    -- extra data
    if bit.get(flags, 1) then
        local elen = reader:readHalf()
        res.extra = reader:read(elen)
        size = size + elen + 2
    end

    -- extractor
    if bit.get(flags, 2) then
        local xlen = reader:readHalf()
        res.extractor = reader:read(xlen)
        size = size + xlen + 2
    end

    -- read size word
    local sizep = reader:readWord()
    size = size + 4
    if sizep == 0xFFFFFFFF then
        -- large-size next
        local large = reader:readLarge()
        size = size + 8
        if large == 0xFFFFFFFFFFFFFFFF then
            -- next 8 bytes are an offset pointing to appended size
            local off = reader:readLarge()
            size = size + 8
            local curpos = reader.index
            reader.index = off
            local appendedSize = reader:readLarge()
            reader.index = curpos
            sizep = appendedSize
        else
            sizep = large
        end
    end

    if sizep == 0 then
        sizep = math.huge
    end

    res.size = sizep

    -- read data
    if sizep == math.huge then
        -- read to EOF
        local remain = #reader.data - reader.index + 1
        res.data = reader:read(remain)
        size = size + remain
    else
        res.data = reader:read(sizep)
        size = size + sizep
    end

    res.truesize = size
    return res
end

-- method registry
local methods = {}
ARC.methods = methods

function ARC.registerMethod(id, encode, decode)
    assert(type(id) == "number", "Invalid argument 1. expected number got " .. type(id))
    if ARC.methods[id] then
        error(("method %d is already registered"):format(id), 2)
    end
    ARC.methods[id] = { encode = encode, decode = decode }
end

-- builtins
ARC.registerMethod(0,
    function(data) return data end,
    function(data) return data end
)

ARC.registerMethod(1,
    function(data) return LibDeflate:CompressDeflate(data) end,
    function(data) return LibDeflate:DecompressDeflate(data) end
)

-- auto helpers
function ARC.autoArchive(data, config)
    local method = (config and config.method) or 0
    local funcs = ARC.methods[method]
    if not funcs then error(("Couldn't encode method %d"):format(method), 2) end
    local encoded = funcs.encode(data)
    return ARC.archive(encoded, config or {})
end

function ARC.autoUnarchive(data)
    local res = ARC.unarchive(data)
    local method = res.method
    local funcs = ARC.methods[method]
    if not funcs then error(("Couldn't decode method %d"):format(method), 2) end
    res.data = funcs.decode(res.data)
    return res
end

-- Many-Archive (Marc)
local Marc = classes.create("ManyArchive")
function Marc:constructor(mode, data)
    return setmetatable({ files = {}, data = data, mode = mode or "w" }, self)
end

function Marc:listArchives()
    assert(self.mode == "r", "not in reading mode")
    local list = {}
    local i = 1
    while i <= #self.data do
        local cur = ARC.unarchive(self.data:sub(i, -1))
        local dat = { name = cur.extension, location = i }
        list[#list + 1] = dat
        i = i + cur.truesize
    end
    self.__cache = list
    return list
end

function Marc:extract(name)
    if not self.__cache then self:listArchives() end
    local entry, j
    for i = 1, #self.__cache do
        local cur = self.__cache[i]
        if cur.name == name then
            entry = cur
            j = i
            break
        end
    end
    if not entry then error("no such entry " .. name, 2) end
    if entry.data then return entry end
    local location = entry.location
    entry = ARC.autoUnarchive(self.data:sub(entry.location, -1))
    entry.location = location
    entry.name = entry.extension
    self.__cache[j] = entry
    self.files[entry.name] = entry
    return entry
end

function Marc:extractAll()
    local files = {}
    local i = 1
    while i <= #self.data do
        local cur = ARC.autoUnarchive(self.data:sub(i, -1))
        cur.name = cur.extension
        files[cur.extension] = cur
        i = i + cur.truesize
    end
    self.__cache = files
    self.files = files
    return files
end

function Marc:addFile(path, data, config)
    self.files[path] = { data = data, config = config or {} }
end

function Marc:compress()
    local res = {}
    for n, v in pairs(self.files) do
        v.config.extension = n
        res[#res + 1] = ARC.autoArchive(v.data, v.config)
    end
    return table.concat(res, "")
end

ARC.marc = Marc

--[[
local ok, arctest = pcall(function()
    return ARC.archive("hello", { extension = "txt" })
end)
if ok then
    print(arctest)
    local ok2, un = pcall(function() return ARC.unarchive(arctest) end)
    if ok2 then print(un.data) end
end

local test = Marc:new("w")
test:addFile("hello.txt", "Hello, World!", { method = 1 })
test:addFile("folder/prog.lua", 'print("Hello, World!")', { method = 1 })
local data = test:compress()
-- local handle = fs.open("test.marc","w")
-- handle:write(data)
-- handle:close()
--]]
-- compressing from folder and decompressing to folder

-- im annoyed of the
--[[
for i=1,#tab do
    local cur = tab[i]
...
end
]]
-- so this is a helper iter from now on
local function each(tab)
    local i = 1
    return function ()
        local value = tab[i]
        i = i + 1
        return value
    end
end
-- back to the compressor and decompressor
function ARC.extract(arc,path)
    assert(type(path) == "string","Expected path to be a string got "..type(path))
    -- extract data
    local marc = Marc:new("r",arc)
    local files = marc:listArchives()
    local function joinpath(a,b)
        if b:sub(1,2) == "//" then
            -- absolute path
            return b:sub(3,-1)
        else
            -- remove leading slashes
            if a:sub(-1,-1) == "/" then
                a = a:sub(1,-2)
            end
            if b:sub(1,1) == "/" then
                b = b:sub(2,-1)
            end
            return a.."/"..b
        end
    end
    -- extract all files
    for i=1,#files do
        local cur = files[i]
        local full = marc:extract(i.name)
        local handle = io.open(joinpath(path,cur.name),"w")
        handle:write(full.data)
        handle:close()
        print(i.name.." -> "..joinpath(path,cur.name))
    end
end
function ARC.compress(path,platform)
    assert(type(path) == "string","Expected path to be a string got "..type(path))
    platform = platform or "terminal"
    if type(platform) == "table" then
        -- expects a read and list function in platform
        local read,list = platform.read,platform.list
        local function recursiveSearch(path,files)
            files = files or {}
            -- attempt list
            local ok,contents = pcall(list,path)
            if not ok then
                files[#files+1] = path
                return path
            end
            for item in each(contents) do
                recursiveSearch(path.."/"..item,files)
            end
            return files
       end
        -- search for files
        local files = recursiveSearch(path)
        -- setup .marc
        local marc = marc:new("w")
        for file in each(files) do
            local contents = read(file)
            marc:addFile(file,contents,{})
        end
        -- compress and return
        return marc:compress()
    elseif platform == "terminal" then
        -- use popen
        local function list(path)
            local contents = {}
            local handle = io.popen("ls "..path)
            for line in handle:lines() do
                contents[#contents+1] = line
            end
            return contents
       end
       local function recursiveSearch(path,files)
            files = files or {}
            -- attempt list
            local ok,contents = pcall(list,path)
            if not ok then
                files[#files+1] = path
                return path
            end
            for item in each(contents) do
                recursiveSearch(path.."/"..item,files)
            end
            return files
       end
        -- search for files
        local files = recursiveSearch(path)
        -- setup .marc
        local marc = marc:new("w")
        for file in each(files) do
            local handle = io.open(file,"r")
            local contents = handle:read(math.huge)
            handle:close()
            marc:addFile(file,contents,{})
        end
        -- compress and return
        return marc:compress()
    elseif platform == "computercraft" or platform == "cc" then
        -- TODO: add ComputerCraft (and CC: Tweaked) support
        return ARC.compress(path,{
                read = function (p)
                        local handle = fs.open(p,"r")
                        if not handle then return nil end
                        local data = handle.readAll()
                        return data
                    end,
                list = function (p)
                        return fs.list(p)
                    end
            })
    elseif platform == "opencomputers" or platerform == "oc" then
        -- TODO: add OpenComputer (OpenOS) and standalone support
    end
    error("Unsupported platform "..platform,2)
end
-- package update format
-- standard package update format
--[[
the standard package update format has a few basic
commands feel free to extend it if you wish
the current standard is as follows

commmand: (typedef)
type : 1 byte
args : (see the command type reference for size)

----

update:
magic "UPDT"
commands : ...command

what this all means i basically we have a command
which all have variable lengths based on type
the way this works is in the extra field you
start with the magic "UPDT" header then
follow with a list of commands for example
a simple patch may follow to turn program

---------
local a = 5
local b = 6
print(a*b)
---------

into

---------
local a = 6
local b = 10
local c = 3
print(a+b-c)
---------

may follow as

REMOVE 11 1 -- remove single character (5)
PATCH 11 1 1 -- insert at index 11 1 character in data starting at 1 (6)
REMOVE 23 1 -- remove single character (6)
PATCH 23 2 2 -- insert at index 23 2 characters in data starting at 2 (10)
PATCH 25 4 12 -- insert at index 25 12 characters in data starting at 4 (local c = 3
)
REMOVE 43 3 -- remove 3 chracters (a*b)
PATCH 43 16 5 -- insert at index 43 5 characters in data starting at index 16 (a+b-c)

and the data being
"610local c = 3
a+b-c"

given these offsets are small we can use
short patch commands this makes the total size 
of the extra data

15 bytes + 4 for the magic so total is 19 bytes of extra data
the actual data contributes 20 bytes so this
upsate is 39 bytes in total instead of
49 bytes by just replacing the file
the creveat is it assumes you have the correct 
version of what ever package so if you dont
have the previous version you have to replace it

------
ok now the actual commands i have issued
------
POINT location (short) : moves the global pointer used for commands (best for short commands to reach further) (this is signed)
REMOVE start amount (short) : removes characters starting from start + globalPointer with the amount specified by amount
PATCH start amount source (short) : inserts data at start + globalPointer with a max of 256 characters with the source pointing to a spot in data to copy from using the specificed amount
MOVE start amount dest (short) : as you can guess it takes data starting from start + globalPointer then moves it to the new relative location at destination (assuming it is removed first then copied)

the long and normal version of all commands use this same scheme just have different bit's set in the last 2 bits (6 and 7) (side note why did it have to be these 2 numbers)
for instance short is 00
half is 01
long is 10
and massive or huge is 11 (64 bit pointer)

-- i should mention there are 2 important commands
REPLACE and DELETE
these commands work by REPLACE as you expect it replaces the entire file with the data
and DELETE just removes the entire file
]]
function ARC.stepPatch(data,newdata,commands)
    local cur = data
    local deleted = false
    local ptr = 1
    for command in each(commands) do
        local type = command.type
        if type == "REPLACE" then
            cur = newdata
        elseif type == "DELETE" then
            cur = ""
            deleted = true
            break
        elseif type == "POINT" then
            ptr = ptr + command.arg[1]
        elseif type == "REMOVE" then
            -- TODO: add REMOVE
            --cur = cur:sub(command.arg[1]+ptr,command.arg[1]+command.arg[2]+ptr)
        elseif type == "PATCH" then
            cur = cur:sub(1,command.arg[1]+ptr-1)..newdata:sub(command.arg[3],command.arg[3]+command.arg[2])..cur:sub(command.arg[1]+ptr,-1)
        elseif type == "MOVE" then
            -- TODO: add MOVE
            --local orginal = cur:sub(command.arg[1]+ptr,command.arg[1]+command.arg[2]+ptr)
        end
    end
    return cur,deleted
end
return ARC
