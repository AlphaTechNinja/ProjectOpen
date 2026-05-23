local bitlib = rawget(_G, "bit32")
if not bitlib and rawget(_G, "package") and package.loaded then
    bitlib = package.loaded.bit32 or package.loaded.bit
end
if not bitlib then
    bitlib = rawget(_G, "bit")
end

if not bitlib then
    local function u32(n)
        return n & 0xffffffff
    end

    bitlib = {}

    function bitlib.band(a, b, ...)
        local r = u32(a) & u32(b)
        local extra = {...}
        for i = 1, #extra do
            r = r & u32(extra[i])
        end
        return u32(r)
    end

    function bitlib.bor(a, b, ...)
        local r = u32(a) | u32(b)
        local extra = {...}
        for i = 1, #extra do
            r = r | u32(extra[i])
        end
        return u32(r)
    end

    function bitlib.bxor(a, b, ...)
        local r = u32(a) ~ u32(b)
        local extra = {...}
        for i = 1, #extra do
            r = r ~ u32(extra[i])
        end
        return u32(r)
    end

    function bitlib.bnot(a)
        return u32(~u32(a))
    end

    function bitlib.lshift(a, n)
        return u32(u32(a) << (n & 31))
    end

    function bitlib.rshift(a, n)
        return u32(u32(a) >> (n & 31))
    end

    function bitlib.arshift(a, n)
        local x = u32(a)
        n = n & 31
        if n == 0 then return x end
        if (x & 0x80000000) ~= 0 then
            return u32((x >> n) | (0xffffffff << (32 - n)))
        end
        return u32(x >> n)
    end

    function bitlib.lrotate(a, n)
        local x = u32(a)
        n = n & 31
        return u32((x << n) | (x >> (32 - n)))
    end

    function bitlib.rrotate(a, n)
        local x = u32(a)
        n = n & 31
        return u32((x >> n) | (x << (32 - n)))
    end

    function bitlib.extract(n, field, width)
        width = width or 1
        local mask = (1 << width) - 1
        return u32(n >> field) & mask
    end
end

if not bitlib.rrotate and bitlib.ror then
    bitlib.rrotate = bitlib.ror
end
if not bitlib.lrotate and bitlib.rol then
    bitlib.lrotate = bitlib.rol
end
if not bitlib.extract then
    function bitlib.extract(n, field, width)
        width = width or 1
        local shifted = bitlib.rshift(n, field)
        local mask = bitlib.lshift(1, width) - 1
        return bitlib.band(shifted, mask)
    end
end

return bitlib
