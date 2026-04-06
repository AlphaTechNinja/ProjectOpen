-- bit plus
local bit = bit or bit32
function bit.sethigh(n,i)
    return bit.bor(n,bit.blshift(1,i))
end
function bit.setlow(n,i)
    return bit.band(n,bit.bnot(bit.blshift(1,i)))
end
function bit.set(n,i,v)
    if v == 1 then v = true end
    if v == 0 then v = false end
    if v then
        return bit.sethigh(n,i)
    else
        return bit.setlow(n,i)
    end
end
function bit.get(n,i)
    return bit.band(n,bit.blshift(1,i)) == bit.blshift(1,i)
end
return bit