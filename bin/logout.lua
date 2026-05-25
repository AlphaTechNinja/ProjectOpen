local args = {...}
local shell = table.remove(args, 1)
local users = require("user")

users.login("guest","")
shell.setenv("USER", users.getUser())
return "logged out...\n"