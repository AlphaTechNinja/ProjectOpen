local M = {}

function M.makeMessage(args)
    if #args == 0 then
        return "hello from package test_app!"
    end
    return "hello from package test_app: " .. table.concat(args, " ")
end

return M
