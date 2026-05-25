local args = {...}
local fs = require("filesystem")
local shell = table.remove(args, 1)

local progs = fs.list(shell.getenv("PROGS"))

-- filter
for i=1, #progs do
    local _, _, name = progs[i]:find("(%w+)%.?%w*")
    progs[i] = name
end

return "\n"..table.concat(progs,"\n").."\n"