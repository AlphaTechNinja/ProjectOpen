local args = {...}
local shell = table.remove(args, 1)
local app = package.import("test_app", { scope = "global" })
app.entry(shell, args)
