local helper = package.import("./helper", { scope = "local" })
local io = require("io")

local M = {}

function M.entry(shell, args)
    io.stdout:write(helper.makeMessage(args) .. "\n")
end

return M
