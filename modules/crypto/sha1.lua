local classes = require("classes")
local bit32 = bit32 or bit

local sha1 = classes.create("sha1")
sha1.__index = sha1

local function rrot(x, n)
    return bit32.rrotate(x, n)
end

function sha1:constructor()
    return setmetatable({
        h0 = 0x67452301,
        h1 = 0xEFCDAB89,
        h2 = 0x98BADCFE,
        h3 = 0x10325476,
        h4 = 0xC3D2E1F0,

        buffer = {},
        buffer_len = 0,
        total_len = 0
    }, sha1)
end

local function process(self, block)
    local w = {}

    for i = 0, 15 do
        local j = i * 4
        w[i] =
            bit32.lshift(block[j+1], 24) +
            bit32.lshift(block[j+2], 16) +
            bit32.lshift(block[j+3], 8) +
            block[j+4]
    end

    for i = 16, 79 do
        w[i] = rrot(bit32.bxor(w[i-3], w[i-8], w[i-14], w[i-16]), 1)
    end

    local a,b,c,d,e =
        self.h0, self.h1, self.h2, self.h3, self.h4

    for i = 0, 79 do
        local f, k

        if i < 20 then
            f = bit32.bor(bit32.band(b,c), bit32.band(bit32.bnot(b), d))
            k = 0x5A827999
        elseif i < 40 then
            f = bit32.bxor(b,c,d)
            k = 0x6ED9EBA1
        elseif i < 60 then
            f = bit32.bor(bit32.band(b,c), bit32.band(b,d), bit32.band(c,d))
            k = 0x8F1BBCDC
        else
            f = bit32.bxor(b,c,d)
            k = 0xCA62C1D6
        end

        local temp = (rrot(a,5) + f + e + k + w[i]) % 2^32
        e = d
        d = c
        c = rrot(b,30)
        b = a
        a = temp
    end

    self.h0 = (self.h0 + a) % 2^32
    self.h1 = (self.h1 + b) % 2^32
    self.h2 = (self.h2 + c) % 2^32
    self.h3 = (self.h3 + d) % 2^32
    self.h4 = (self.h4 + e) % 2^32
end

function sha1:update(data)
    for i = 1, #data do
        self.buffer_len = self.buffer_len + 1
        self.buffer[self.buffer_len] = data:byte(i)

        if self.buffer_len == 64 then
            process(self, self.buffer)
            self.buffer = {}
            self.buffer_len = 0
        end
    end

    self.total_len = self.total_len + #data
end

function sha1:final()
    local bit_len = self.total_len * 8

    self:update(string.char(0x80))

    while self.buffer_len ~= 56 do
        self:update(string.char(0x00))
    end

    local len_bytes = {}
    for i = 7, 0, -1 do
        len_bytes[#len_bytes+1] =
            string.char(bit32.extract(bit_len, i*8, 8))
    end

    self:update(table.concat(len_bytes))

    return string.format(
        "%08x%08x%08x%08x%08x",
        self.h0, self.h1, self.h2, self.h3, self.h4
    )
end

return sha1