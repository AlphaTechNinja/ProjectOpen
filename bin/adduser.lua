local args = {...}
local shell = table.remove(args, 1)
local users = require("user")

local name = args[1]
local level = tonumber(args[2] or "")
local password = args[3]

if not name or not level then
    errorf("Usage: adduser <name> <level> [password]", 2)
end

users.create(name, level, password)
return ("created user '%s' level=%s\n"):format(name, tostring(level))
