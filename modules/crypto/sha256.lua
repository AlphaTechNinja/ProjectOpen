local classes = require("classes")
local bit32 = bit32 or bit

local sha256 = classes.create("sha256")
sha256.__index = sha256

local K = {
0x428a2f98,0x71374491,0xb5c0fbcf,0xe9b5dba5,0x3956c25b,0x59f111f1,0x923f82a4,0xab1c5ed5,
0xd807aa98,0x12835b01,0x243185be,0x550c7dc3,0x72be5d74,0x80deb1fe,0x9bdc06a7,0xc19bf174,
0xe49b69c1,0xefbe4786,0x0fc19dc6,0x240ca1cc,0x2de92c6f,0x4a7484aa,0x5cb0a9dc,0x76f988da,
0x983e5152,0xa831c66d,0xb00327c8,0xbf597fc7,0xc6e00bf3,0xd5a79147,0x06ca6351,0x14292967,
0x27b70a85,0x2e1b2138,0x4d2c6dfc,0x53380d13,0x650a7354,0x766a0abb,0x81c2c92e,0x92722c85,
0xa2bfe8a1,0xa81a664b,0xc24b8b70,0xc76c51a3,0xd192e819,0xd6990624,0xf40e3585,0x106aa070,
0x19a4c116,0x1e376c08,0x2748774c,0x34b0bcb5,0x391c0cb3,0x4ed8aa4a,0x5b9cca4f,0x682e6ff3,
0x748f82ee,0x78a5636f,0x84c87814,0x8cc70208,0x90befffa,0xa4506ceb,0xbef9a3f7,0xc67178f2
}

local function rrot(x,n) return bit32.rrotate(x,n) end
local function rshift(x,n) return bit32.rshift(x,n) end

function sha256:constructor()
    return setmetatable({
        h0 = 0x6a09e667,
        h1 = 0xbb67ae85,
        h2 = 0x3c6ef372,
        h3 = 0xa54ff53a,
        h4 = 0x510e527f,
        h5 = 0x9b05688c,
        h6 = 0x1f83d9ab,
        h7 = 0x5be0cd19,

        buffer = {},
        buffer_len = 0,
        total_len = 0
    }, sha256)
end

local function Ch(x,y,z)
    return bit32.bxor(bit32.band(x,y), bit32.band(bit32.bnot(x), z))
end

local function Maj(x,y,z)
    return bit32.bxor(bit32.band(x,y), bit32.band(x,z), bit32.band(y,z))
end

local function sigma0(x)
    return rrot(x,2) ~ rrot(x,13) ~ rrot(x,22)
end

local function sigma1(x)
    return rrot(x,6) ~ rrot(x,11) ~ rrot(x,25)
end

local function delta0(x)
    return rrot(x,7) ~ rrot(x,18) ~ rshift(x,3)
end

local function delta1(x)
    return rrot(x,17) ~ rrot(x,19) ~ rshift(x,10)
end

local function process(self, block)
    local w = {}

    for i=0,15 do
        local j=i*4
        w[i] =
            bit32.lshift(block[j+1],24) +
            bit32.lshift(block[j+2],16) +
            bit32.lshift(block[j+3],8) +
            block[j+4]
    end

    for i=16,63 do
        w[i] = (delta1(w[i-2]) + w[i-7] + delta0(w[i-15]) + w[i-16]) % 2^32
    end

    local a,b,c,d,e,f,g,h =
        self.h0,self.h1,self.h2,self.h3,
        self.h4,self.h5,self.h6,self.h7

    for i=0,63 do
        local t1 = (h + sigma1(e) + Ch(e,f,g) + K[i+1] + w[i]) % 2^32
        local t2 = (sigma0(a) + Maj(a,b,c)) % 2^32

        h=g
        g=f
        f=e
        e=(d + t1) % 2^32
        d=c
        c=b
        b=a
        a=(t1 + t2) % 2^32
    end

    self.h0=(self.h0+a)%2^32
    self.h1=(self.h1+b)%2^32
    self.h2=(self.h2+c)%2^32
    self.h3=(self.h3+d)%2^32
    self.h4=(self.h4+e)%2^32
    self.h5=(self.h5+f)%2^32
    self.h6=(self.h6+g)%2^32
    self.h7=(self.h7+h)%2^32
end

function sha256:update(data)
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

function sha256:final()
    local bit_len=self.total_len*8

    self:update(string.char(0x80))

    while self.buffer_len~=56 do
        self:update(string.char(0x00))
    end

    local len={}
    for i=7,0,-1 do
        len[#len+1]=string.char(bit32.extract(bit_len,i*8,8))
    end

    self:update(table.concat(len))

    return string.format(
        "%08x%08x%08x%08x%08x%08x%08x%08x",
        self.h0,self.h1,self.h2,self.h3,
        self.h4,self.h5,self.h6,self.h7
    )
end

return sha256