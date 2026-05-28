local classes = require("classes")
local io = require("io")
local term = require("terminal")
local fs = require("filesystem")
local users = require("user")
local Shell = require("shells.Shell")

local shell = classes.create("SimpleShell", Shell)

shell.alias = {}
shell.cmdVars = { GLOBAL = _G }
shell.outpipe = io.stdout
shell.runningProg = nil

shell._env = {
    CWD = "/home/",
    HOME = "/home/",
    USER = users.getUser(),
    USERPATH = shell.wrapforenv(function()
        return "/users/" .. users.getUser().name .. "/"
    end),
    HOMEPATH = shell.wrapforenv(function()
        return "/users/" .. users.getUser().name .. "/home/"
    end),
    APPSPATH = shell.wrapforenv(function()
        return "/users/" .. users.getUser().name .. "/apps/"
    end),
    GLOBALAPPSPATH = "/users/kernel/apps/",
    PROGS = "/bin/",
    NONE = ""
}

shell.searchHooks = {}
shell:addSearchHook("userApps", function(sh, name)
    local candidate = fs.combine(sh:getenv("APPSPATH"):__shellparse(), name)
    if fs.exists(candidate) then
        return candidate
    end
    if fs.exists(candidate .. ".lua") then
        return candidate .. ".lua"
    end
end)
shell:addSearchHook("globalApps", function(sh, name)
    local base = sh:getenv("GLOBALAPPSPATH")
    if type(base) == "table" and base.__shellparse then
        base = base:__shellparse()
    end
    local candidate = fs.combine(base, name)
    if fs.exists(candidate) then
        return candidate
    end
    if fs.exists(candidate .. ".lua") then
        return candidate .. ".lua"
    end
end)

function shell:run(command, out)
    out = out or self.outpipe
    local assignName, assignValueRaw = command:match("^%s*%$([%a_][%w_]*)%s*=%s*(.-)%s*$")
    if assignName then
        local current = self:getenv(assignName)
        if type(current) == "table" and not current.__shellset then
            io.stderr:write(("env var '$%s' is read-only\n"):format(assignName))
            return nil, "Read-only env var"
        end
        local value = assignValueRaw:gsub("^%s+", ""):gsub("%s+$", "")
        if #value >= 2 then
            local q1, q2 = value:sub(1, 1), value:sub(-1)
            if (q1 == "\"" and q2 == "\"") or (q1 == "'" and q2 == "'") then
                value = value:sub(2, -2)
            end
        end
        if value == "true" then
            value = true
        elseif value == "false" then
            value = false
        else
            local num = tonumber(value)
            if num ~= nil then
                value = num
            end
        end
        self:setenv(assignName, value)
        return value
    end
    local phrased = self:phrase(command)
    local target = table.remove(phrased, 1)
    if not target or target == "" then
        return true
    end

    local currentUser = users.getUser()
    if currentUser and currentUser.level == 0 then
        local checkTarget = target
        if self.alias[checkTarget] then
            checkTarget = self.alias[checkTarget]
        end
        local cmd = checkTarget:gsub("^.*/", ""):gsub("%.lua$", "")
        if cmd ~= "login" and cmd ~= "whoami" then
            io.stderr:write("guest access: only 'login' and 'whoami' are allowed\n")
            return nil, "Guest access denied"
        end
    end

    local progPath = fs.combine(self._env.PROGS, target)
    if target:sub(1, 1) == "/" then
        progPath = target
    elseif target:sub(1, 1) == "~" then
        progPath = self:getenv("APPSPATH"):__shellparse() .. target:sub(2)
    else
        progPath = self:resolveProgram(target) or progPath
    end

    if fs.exists(progPath) then
        self.runningProg = progPath
        local ok, err = dofile(progPath, self, table.unpack(phrased))
        if not ok and err then
            io.stderr:write(("error in command '%s': %s\n"):format(target, err))
            return nil, "Failed to execute"
        end
        if ok then
            out:write(ok)
        end
        return ok
    elseif self.alias[target] then
        self.runningProg = self.alias[target]
        local aliasPath = fs.combine(self._env.PROGS, self.alias[target])
        if fs.exists(aliasPath) then
            local ok, err = dofile(aliasPath, self, table.unpack(phrased))
            if not ok and err then
                io.stderr:write(("error in alias '%s': %s\n"):format(target, err))
                return nil, "Failed to execute"
            end
            if ok then
                out:write(ok)
            end
            return ok
        end
    end

    io.stderr:write(("command not found: %s\n"):format(target))
    return false
end

function shell:prompt()
    io.stdout:write(fs.simplify(self._env.CWD) .. "/@" .. self:getPromptUser() .. ">")
    local command = term.read()
    self:run(command)
end

function io.popen(command)
    local output = { __data = {} }
    function output:write(data)
        table.insert(self.__data, data)
    end
    local ok, err = pcall(function()
        shell:run(command, output)
    end)
    if not ok and err then
        return nil, err
    end
    return table.concat(output.__data, "")
end

local canGet = true
function shell:getEnv()
    if not canGet then
        return
    end
    canGet = false
    return self._env
end

return shell
