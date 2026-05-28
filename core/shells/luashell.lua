local io = require("io")
local term = require("terminal")
local fs = require("filesystem")
local shell = require("shells.simpleshell")

local _env = shell:getEnv()

local shellW = setmetatable({}, {
    __index = function(_, k)
        local name = shell:resolveProgramName(k)
        if not name then
            return nil
        end
        return function(...)
            return shell:run(k .. " " .. table.concat({...}, " "))
        end
    end
})

local envVars = setmetatable({}, {
    __index = function(_, k)
        return _env[k]
    end,
    __newindex = function(_, k, v)
        _env[k] = v
    end,
    __pairs = function()
        return pairs(_env)
    end
})

local env = {
    exe = shellW,
    env = envVars,
    fs = fs,
    io = io,
    term = term
}

setmetatable(env, {
    __index = function(_, k)
        if _G[k] ~= nil then
            return _G[k]
        end
        local ev = envVars[k]
        if ev and type(ev) == "table" and ev.__shellparse then
            return ev:__shellparse()
        end
        return ev
    end,
    __newindex = function(t, k, v)
        local ev = envVars[k]
        if ev and type(ev) == "table" and ev.__shellset then
            ev.__shellset(ev, v)
        else
            rawset(t, k, v)
        end
    end
})

local function execute(str)
    if str:sub(1, 1) == "@" then
        shell:run(str:sub(2))
        return
    end

    local func, err = load(str, "=command", "t", env)
    if not func and err then
        io.stderr:write("Failed to load code (reason):" .. err)
        return
    end

    local res = { pcall(func) }
    if not res[1] and res[2] then
        io.stderr:write("Failed to execute code (reason):" .. res[2] .. "\n")
        return
    end
    if #res > 1 then
        io.stdout:write(table.concat(res, " ", 2) .. "\n")
    end
end

function shell:prompt()
    io.stdout:write(fs.simplify(_env.CWD) .. "/@" .. self:getPromptUser() .. ">")
    local command = term.read()
    execute(command)
end

return shell
