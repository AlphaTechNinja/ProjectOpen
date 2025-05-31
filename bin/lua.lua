local args = {...}
local shell = table.remove(args, 1)
local fs = require("filesystem")
local io = require("io")

if #args == 0 then
    -- Interactive Lua REPL
    local env = setmetatable({}, { __index = _ENV })
    print("Lua Shell (type 'exit' or Ctrl+D to quit)")
    while true do
        io.stdout:write("> ")
        local line = io.stdin:read()
        if not line or line == "exit" then break end

        -- Try to wrap in "return" to mimic expression evaluation
        local chunk, err = load("return " .. line, "=stdin", "t", env)
        if not chunk then
            chunk, err = load(line, "=stdin", "t", env)
        end

        if not chunk then
            io.stderr:write("syntax error: " .. tostring(err) .. "\n")
        else
            local ok, result = pcall(chunk)
            if not ok then
                io.stderr:write("runtime error: " .. tostring(result) .. "\n")
            elseif result ~= nil then
                print(result)
            end
        end
    end
    return
else
    -- Run a Lua file
    local path = shell.resolve(args[1])
    if not fs.exists(path) then
        errorf("file '%s' not found", args[1], 2)
    end

    local fn, err = loadfile(path, "t", _ENV)
    if not fn then
        errorf("error loading '%s': %s", path, err, 2)
    end

    local ok, result = pcall(fn, table.unpack(args, 2))
    if not ok then
        errorf("error running '%s': %s", path, result, 2)
    end

    return result -- optional output for pipes
end
return ""