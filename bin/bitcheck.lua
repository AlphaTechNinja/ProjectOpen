local args = {...}
local shell = table.remove(args, 1)

local lines = {}
lines[#lines + 1] = ("global bit32: %s"):format(type(bit32))
lines[#lines + 1] = ("global bit: %s"):format(type(bit))

local ok1, m1 = pcall(require, "bit32")
lines[#lines + 1] = ("require('bit32'): %s (%s)"):format(ok1 and "ok" or "fail", type(m1))

local ok2, m2 = pcall(require, "bit")
lines[#lines + 1] = ("require('bit'): %s (%s)"):format(ok2 and "ok" or "fail", type(m2))

return table.concat(lines, "\n") .. "\n"
