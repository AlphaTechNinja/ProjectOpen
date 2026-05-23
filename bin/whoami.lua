local args = {...}
local shell = table.remove(args, 1)
local users = require("user")

local user = users.getUser()
local permName = users.permissionName(user.level) or "custom"
return ("%s (level=%s, %s)\n"):format(user.name, tostring(user.level), permName)
