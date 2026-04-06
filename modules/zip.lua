local classes = require("classes")
local Stream, Reference = table.unpack(require("AdvancedStream"))
local LibDeflate = require("libDeflate")
local bit = bit or bit32

-- constants
local MAX_HALF = 0xFFFF
local MAX_WORD = 0xFFFFFFFF

-- CRC32 table generation
local crc32_table = {}
for i = 0, 255 do
    local crc = i
    for _ = 1, 8 do
        if bit.band(crc, 1) == 1 then
            crc = bit.bxor(bit.rshift(crc, 1), 0xEDB88320)
        else
            crc = bit.rshift(crc, 1)
        end
    end
    crc32_table[i] = crc
end

local function crc32(str)
    local crc = 0xFFFFFFFF
    for i = 1, #str do
        local b = string.byte(str, i)
        local idx = bit.band(bit.bxor(crc, b), 0xFF)
        crc = bit.bxor(crc32_table[idx], bit.rshift(crc, 8))
    end
    return bit.bnot(crc) % 0x100000000
end

-- DOS date/time conversion
local function dosDateTime(t)
    local date = os.date("*t", t)
    local dosTime = bit.lshift(date.hour, 11) + bit.lshift(date.min, 5) + math.floor(date.sec / 2)
    local dosDate = bit.lshift(date.year - 1980, 9) + bit.lshift(date.month, 5) + date.day
    return dosTime, dosDate
end

-- =============================
-- ZipWriter
-- =============================
local ZipWriter = classes.create("ZipWriter")

function ZipWriter:constructor()
    return setmetatable({ writer = Stream:new(""), files = {}, metadata = {} }, self)
end

function ZipWriter:setFile(path, data, metadata)
    self.metadata[path] = metadata or {}
    self.files[path] = data
end

function ZipWriter:writeLocalHeader(path, data, compressedData, crcVal, config, meta)
    local writer = self.writer
    local lastmodtime, lastmoddate = dosDateTime(meta.lastmod or os.time())
    local name = path
    local extra = meta.extra or ""

    writer:write(0x50, 0x4B, 0x03, 0x04) -- local file header signature
    writer:writeHalf(meta.version or config.version or 20)
    writer:writeHalf(meta.bitflag or config.bitflag or 0)
    writer:writeHalf(config.method or 8)
    writer:writeHalf(lastmodtime)
    writer:writeHalf(lastmoddate)
    writer:writeWord(crcVal)
    writer:writeWord(#data)
    writer:writeWord(#compressedData)
    writer:writeHalf(math.min(#name, MAX_HALF))
    writer:writeHalf(math.min(#extra, MAX_HALF))
    writer:write(name)
    writer:write(extra)
    writer:write(compressedData)

    return Reference:new(writer, writer.index - #compressedData)
end

function ZipWriter:writeCentralHeader(path, dataSize, compressedSize, crcVal, reference, config, meta)
    local writer = self.writer
    local lastmodtime, lastmoddate = dosDateTime(meta.lastmod or os.time())
    local name = path
    local extra = meta.extra or ""
    local comment = meta.comment or ""

    writer:write(0x50, 0x4B, 0x01, 0x02) -- central directory signature
    writer:writeHalf(meta.version or config.version or 20)
    writer:writeHalf(config.extractversion or 20)
    writer:writeHalf(meta.bitflag or config.bitflag or 0)
    writer:writeHalf(config.method or 8)
    writer:writeHalf(lastmodtime)
    writer:writeHalf(lastmoddate)
    writer:writeWord(crcVal)
    writer:writeWord(compressedSize)
    writer:writeWord(dataSize)
    writer:writeHalf(math.min(#name, MAX_HALF))
    writer:writeHalf(math.min(#extra, MAX_HALF))
    writer:writeHalf(math.min(#comment, MAX_HALF))
    writer:writeHalf(meta.diskstart or 0)
    writer:writeHalf(meta.internalattr or 0)
    writer:writeWord(meta.externalattr or 0)
    writer:writeWord(reference.index)
    writer:write(name)
    writer:write(extra)
    writer:write(comment)
end

function ZipWriter:compress(level, config)
    local writer = self.writer
    writer.data = ""
    writer.index = 1

    local compressed, crc, references = {}, {}, {}

    -- Write local headers + compressed data
    for path, data in pairs(self.files) do
        local meta = self.metadata[path] or {}
        compressed[path] = LibDeflate:CompressDeflate(data, level)
        crc[path] = crc32(data)
        references[path] = self:writeLocalHeader(path, data, compressed[path], crc[path], config, meta)
        references[path].name = path
    end

    -- Write central directory
    local cd_start = writer.index
    for path, ref in pairs(references) do
        local meta = self.metadata[path] or {}
        self:writeCentralHeader(path, #(self.files[path]), #(compressed[path]), crc[path], ref, config, meta)
    end
    local cd_size = writer.index - cd_start

    -- End of central directory
    writer:write(0x50, 0x4B, 0x05, 0x06)
    writer:writeHalf(math.min(config.disknumber or 0, MAX_HALF))
    writer:writeHalf(#references)
    writer:writeHalf(#references)
    writer:writeWord(cd_size)
    writer:writeWord(cd_start)
    writer:writeHalf(#(config.comment or ""))
    writer:write(config.comment or "")
end

-- =============================
-- ZipReader
-- =============================
local ZipReader = classes.create("ZipReader")

function ZipReader:constructor(data)
    self.reader = Stream:new(data)
    self.files = {}
    self.central = {}
end

local function readHalf(stream)
    local b1, b2 = stream:read(2):byte(1,2)
    return b1 + bit32.lshift(b2, 8)
end

local function readWord(stream)
    local b1, b2, b3, b4 = stream:read(4):byte(1,4)
    return b1 + bit32.lshift(b2,8) + bit32.lshift(b3,16) + bit32.lshift(b4,24)
end

function ZipReader:findEOCD()
    local data = self.reader.data
    local len = #data
    for i = len - 22, math.max(len - 65536, 1), -1 do
        if data:byte(i) == 0x50 and data:byte(i+1) == 0x4B and
           data:byte(i+2) == 0x05 and data:byte(i+3) == 0x06 then
            self.eocdOffset = i
            return i
        end
    end
    error("EOCD not found")
end

function ZipReader:parseEOCD()
    local stream = Stream:new(self.reader.data)
    stream.index = self.eocdOffset
    stream:read(4) -- skip signature
    self.diskNumber = readHalf(stream)
    self.cdDiskNumber = readHalf(stream)
    self.totalEntriesDisk = readHalf(stream)
    self.totalEntries = readHalf(stream)
    self.cdSize = readWord(stream)
    self.cdOffset = readWord(stream)
    local commentLen = readHalf(stream)
    self.comment = stream:read(commentLen)
end

function ZipReader:parseCentralDirectory()
    local stream = Stream:new(self.reader.data)
    stream.index = self.cdOffset
    for _ = 1, self.totalEntries do
        local sig = stream:read(4)
        assert(sig:byte(1,4) == 0x50 and sig:byte(2) == 0x4B and sig:byte(3) == 0x01 and sig:byte(4) == 0x02, "Invalid central dir signature")
        local madeVersion = readHalf(stream)
        local extractVersion = readHalf(stream)
        local bitflag = readHalf(stream)
        local method = readHalf(stream)
        local lastmodtime = readHalf(stream)
        local lastmoddate = readHalf(stream)
        local crc = readWord(stream)
        local compressedSize = readWord(stream)
        local uncompressedSize = readWord(stream)
        local nameLen = readHalf(stream)
        local extraLen = readHalf(stream)
        local commentLen = readHalf(stream)
        local diskStart = readHalf(stream)
        local internalAttr = readHalf(stream)
        local externalAttr = readWord(stream)
        local localHeaderOffset = readWord(stream)
        local name = stream:read(nameLen)
        local extra = stream:read(extraLen)
        local comment = stream:read(commentLen)

        table.insert(self.central, {
            name = name,
            crc = crc,
            compressedSize = compressedSize,
            uncompressedSize = uncompressedSize,
            method = method,
            offset = localHeaderOffset,
            bitflag = bitflag,
            -- extra
            madeVersion = madeVersion,
            extractVersion = extractVersion,
            lastmodtime = lastmodtime,
            lastmoddate = lastmoddate,
            diskStart=diskStart,
            internalAttr=internalAttr,
            externalAttr=externalAttr,
            extra=extra,
            comment=comment
        })
    end
end

function ZipReader:listFiles()
    local list = {}
    for _, file in ipairs(self.central) do
        table.insert(list, file.name)
    end
    return list
end

function ZipReader:extract(name)
    for _, file in ipairs(self.central) do
        if file.name == name then
            local stream = Stream:new(self.reader.data)
            stream.index = file.offset
            stream:read(4) -- skip local header signature
            stream:read(2*6) -- skip version, flags, method, time/date
            local crc = readWord(stream)
            local uncompressedSize = readWord(stream)
            local compressedSize = readWord(stream)
            local nameLen = readHalf(stream)
            local extraLen = readHalf(stream)
            stream:read(nameLen + extraLen)
            local data = stream:read(file.compressedSize)
            if file.method == 8 then -- deflate
                data = LibDeflate:DecompressDeflate(data)
            end
            -- validate crc32
            local computed = crc32(data)
            if computed ~= crc then
                return nil,"Failed CRC32 check"
            end
            return data
        end
    end
    return nil
end

-- =============================
-- Return module
-- =============================
return {
    ZipWriter = ZipWriter,
    ZipReader = ZipReader
}
