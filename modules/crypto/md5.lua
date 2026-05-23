local classes = require("classes")
local bit32 = require("crypto.bitcompat")

local md5 = classes.create("md5")
md5.__index = md5

local function leftrotate(x,n)
    return bit32.lrotate(x,n)
end

local function F(x,y,z) return bit32.bor(bit32.band(x,y), bit32.band(bit32.bnot(x),z)) end
local function G(x,y,z) return bit32.bor(bit32.band(x,z), bit32.band(y,bit32.bnot(z))) end
local function H(x,y,z) return bit32.bxor(x,y,z) end
local function I(x,y,z) return bit32.bxor(y, bit32.bor(x, bit32.bnot(z))) end

function md5:constructor()
    return setmetatable({
        a=0x67452301,
        b=0xefcdab89,
        c=0x98badcfe,
        d=0x10325476,

        buffer={},
        buffer_len=0,
        total_len=0
    }, md5)
end

local K = {}
for i=1,64 do
    K[i]=math.floor(math.abs(math.sin(i))*2^32)
end

local S = {
7,12,17,22, 7,12,17,22, 7,12,17,22, 7,12,17,22,
5,9,14,20, 5,9,14,20, 5,9,14,20, 5,9,14,20,
4,11,16,23,4,11,16,23,4,11,16,23,4,11,16,23,
6,10,15,21,6,10,15,21,6,10,15,21,6,10,15,21
}

local function process(self, block)
    local w={}

    for i=0,15 do
        local j=i*4
        w[i]=
            block[j+1] +
            bit32.lshift(block[j+2],8) +
            bit32.lshift(block[j+3],16) +
            bit32.lshift(block[j+4],24)
    end

    local a,b,c,d=self.a,self.b,self.c,self.d

    for i=0,63 do
        local f,g

        if i<16 then
            f=F(b,c,d)
            g=i
        elseif i<32 then
            f=G(b,c,d)
            g=(5*i+1)%16
        elseif i<48 then
            f=H(b,c,d)
            g=(3*i+5)%16
        else
            f=I(b,c,d)
            g=(7*i)%16
        end

        local temp=d
        d=c
        c=b
        b=(b + leftrotate((a+f+K[i+1]+w[g])%2^32,S[i+1]))%2^32
        a=temp
    end

    self.a=(self.a+a)%2^32
    self.b=(self.b+b)%2^32
    self.c=(self.c+c)%2^32
    self.d=(self.d+d)%2^32
end

function md5:update(data)
    for i=1,#data do
        self.buffer_len=self.buffer_len+1
        self.buffer[self.buffer_len]=data:byte(i)

        if self.buffer_len==64 then
            process(self,self.buffer)
            self.buffer={}
            self.buffer_len=0
        end
    end

    self.total_len=self.total_len+#data
end

function md5:final()
    local bit_len=self.total_len*8

    self:update(string.char(0x80))

    while self.buffer_len~=56 do
        self:update(string.char(0x00))
    end

    local len={}
    for i=0,7 do
        len[#len+1]=string.char(bit32.extract(bit_len,i*8,8))
    end

    self:update(table.concat(len))

    return string.format(
        "%08x%08x%08x%08x",
        self.a,self.b,self.c,self.d
    )
end

return md5
