-- getting popm ready only list pcakges for now
local args = {...}
local shell = table.remove(args,1)
local fs = kernel.filesystem
local popm = require("popm")
args[1] = args[1] or "-l"
if args[1] == "-l" then
    return table.concat(popm.packages,"\n").."\n"
elseif args[1] == "-v" then
    -- list versions of a packages
    if popm.packages[args[2]] then
        return table.concat(fs.list(fs.combine("/packages/",args[2])),"\n").."\n"
    end
end