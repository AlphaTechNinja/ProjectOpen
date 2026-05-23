local args = {...}
local shell = table.remove(args, 1)
local users = require("user")

local name = args[1]
local password = args[2]

if not name then
    errorf("Usage: login <name> [password]", 2)
end

users.login(name, password)
shell.setenv("USER", users.getUser())
return ("logged in as '%s'\n"):format(name)
