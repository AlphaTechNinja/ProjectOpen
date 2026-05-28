local classes = require("classes")
local fs = require("filesystem")
local io = require("io")
local users = require("user")

local Shell = classes.create("Shell")
local function currentShell(fallback)
    return (kernel and kernel.shell) or fallback
end

function Shell.addSearchHook(self, name, hook)
    local sh = self
    if type(sh) ~= "table" then
        hook = name
        name = self
        sh = currentShell(Shell)
    end
    checkArg(1, name, "string")
    checkArg(2, hook, "function")
    sh.searchHooks = sh.searchHooks or {}
    sh.searchHooks[name] = hook
end

function Shell.removeSearchHook(self, name)
    local sh = self
    if type(sh) ~= "table" then
        name = self
        sh = currentShell(Shell)
    end
    checkArg(1, name, "string")
    if not sh.searchHooks then
        return false
    end
    local had = sh.searchHooks[name] ~= nil
    sh.searchHooks[name] = nil
    return had
end

function Shell.wrapforenv(func)
    return { __shellparse = func }
end

function Shell.getenv(self, name)
    local sh = self
    if type(sh) ~= "table" then
        name = self
        sh = currentShell(Shell)
    end
    checkArg(1, name, "string")
    return sh._env[name]
end

function Shell.setenv(self, name, value)
    local sh = self
    if type(sh) ~= "table" then
        value = name
        name = self
        sh = currentShell(Shell)
    end
    checkArg(1, name, "string")
    local vt = type(value)
    if vt ~= "table" and vt ~= "string" and vt ~= "number" and vt ~= "boolean" then
        value = tostring(value)
    end
    local ev = sh._env[name]
    if ev and ev.__shellset then
        ev.__shellset(ev, value)
        return
    end
    sh._env[name] = value
end

function Shell.resolve(self, path)
    local sh = self
    if type(sh) ~= "table" then
        path = self
        sh = currentShell(Shell)
    end
    if path:sub(1, 1) == "/" then
        return path
    end
    return fs.simplify(fs.combine(sh._env.CWD, path))
end

function Shell.resolveProgram(self, name)
    local sh = self
    if type(sh) ~= "table" then
        name = self
        sh = currentShell(Shell)
    end
    local progPath = fs.combine(sh._env.PROGS, name)
    if fs.exists(progPath) then
        return progPath
    elseif sh.alias[name] then
        local aliasPath = fs.combine(sh._env.PROGS, sh.alias[name])
        if fs.exists(aliasPath) then
            return aliasPath
        end
    end
    if sh.searchHooks then
        for _, hook in pairs(sh.searchHooks) do
            local ok, resolved = pcall(hook, sh, name)
            if ok and type(resolved) == "string" and fs.exists(resolved) then
                return resolved
            end
        end
    end
    return nil, "No such program"
end

function Shell.resolveProgramName(self, name)
    local sh = self
    if type(sh) ~= "table" then
        name = self
        sh = currentShell(Shell)
    end
    local resolved = sh:resolveProgram(name)
    if resolved then
        local filename = resolved:match("([^/]+)$")
        if filename then
            return filename
        end
        return name
    end
    return nil, "No such program"
end

function Shell.phrase(self, command)
    local sh = self
    if type(sh) ~= "table" then
        command = self
        sh = currentShell(Shell)
    end
    checkArg(1, command, "string")
    local tokens = {}
    for token in command:gmatch("[%S]+") do
        token = token:gsub("%$(%w+)", function(var)
            local v = sh._env[var] or ""
            if type(v) == "table" and v.__shellparse then
                v = v:__shellparse()
            end
            if type(v) ~= "string" then
                v = tostring(v)
            end
            return v
        end)
        table.insert(tokens, token)
    end
    return tokens
end

function Shell.setalias(self, cmd, alias)
    local sh = self
    if type(sh) ~= "table" then
        alias = cmd
        cmd = self
        sh = currentShell(Shell)
    end
    sh.alias[alias] = cmd
end

function Shell.execute(self, ...)
    local sh = self
    local args = {...}
    if type(sh) ~= "table" then
        sh = currentShell(Shell)
        table.insert(args, 1, self)
    end
    sh:run(table.concat(args, " "))
end

function Shell.executePipe(self, out, ...)
    local sh = self
    if type(sh) ~= "table" then
        sh = currentShell(Shell)
        return sh:run(table.concat({out, ...}, " "), nil)
    end
    sh:run(table.concat({...}, " "), out)
end

function Shell.getCmdVars(self, name)
    local sh = self
    if type(sh) ~= "table" then
        name = self
        sh = currentShell(Shell)
    end
    if not sh.cmdVars[name] then
        sh.cmdVars[name] = {}
    end
    return sh.cmdVars[name]
end

function Shell.setCmdVar(self, name, key, value)
    local sh = self
    if type(sh) ~= "table" then
        value = key
        key = name
        name = self
        sh = currentShell(Shell)
    end
    sh:getCmdVars(name)[key] = value
end

function Shell.getCmdVar(self, name, key)
    local sh = self
    if type(sh) ~= "table" then
        key = name
        name = self
        sh = currentShell(Shell)
    end
    return sh:getCmdVars(name)[key]
end

function Shell.getLocalVars(self)
    local sh = self
    if type(sh) ~= "table" then
        sh = currentShell(Shell)
    end
    return sh:getCmdVars(sh.runningProg or "GLOBAL")
end

function Shell.setLocalVar(self, key, value)
    local sh = self
    if type(sh) ~= "table" then
        value = key
        key = self
        sh = currentShell(Shell)
    end
    sh:getLocalVars()[key] = value
end

function Shell.getLocalVar(self, key)
    local sh = self
    if type(sh) ~= "table" then
        key = self
        sh = currentShell(Shell)
    end
    return sh:getLocalVars()[key]
end

function Shell.getPromptUser(self)
    local sh = self
    if type(sh) ~= "table" then
        sh = currentShell(Shell)
    end
    local uname = sh._env.USER
    if type(uname) == "table" then
        uname = uname.name
    end
    if not uname or uname == "" then
        uname = users.getUser().name
    end
    return tostring(uname)
end

function Shell.getEnv(self)
    local sh = self
    if type(sh) ~= "table" then
        sh = currentShell(Shell)
    end
    return sh._env
end

function Shell:run()
    error("Shell:run must be implemented by child shell", 2)
end

function Shell:prompt()
    error("Shell:prompt must be implemented by child shell", 2)
end

os.setenv = function(name, value)
    if kernel and kernel.shell and kernel.shell.setenv then
        kernel.shell:setenv(name, value)
        return
    end
end
os.getenv = function(name)
    if kernel and kernel.shell and kernel.shell.getenv then
        return kernel.shell:getenv(name)
    end
end

return Shell
