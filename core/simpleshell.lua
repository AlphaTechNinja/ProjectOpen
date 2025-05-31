-- a simple test shell
local io = require("io")
local term = require("terminal")
local fs = require("filesystem")
local Stream = require("Stream")
local shell = {}
local _env = {
    CWD="/home/",
    HOME="/home/",
    USER="root",
    PROGS="/bin/",
    NONE = ""
}
shell.alias = {}
shell.cmdVars = {GLOBAl = _G}
shell.outpipe = io.stdout -- just uses stdout as the pipe should be switched to shell.pipe when executing in bash mode
--shell.pipe = Stream:new() -- we arn't using an IO pipe due to custom behavior
-- maybe add autocompletion may be a pain to intergrate with term.read but might be able to be done by modding the methods
-- but we can allow suggestions
function shell.resolve(path)
    if path:sub(1,1) == "/" then
        -- absolute
        return path
    else
        return fs.simplify(fs.combine(_env.CWD,path))
    end
end
function shell.resolveProgram(name)
    local progPath = fs.combine(_env.PROGS, name)
    if fs.exists(progPath) then
        return progPath
    elseif shell.alias[name] then
        local aliasPath = fs.combine(_env.PROGS, shell.alias[name])
        if fs.exists(aliasPath) then
            return aliasPath
        end
    end
    return nil, "No such program"
end
function shell.resolveProgramName(name)
    -- useful for help it resolves just the name
    local progPath = fs.combine(_env.PROGS, name)
    if fs.exists(progPath) then
        return name
    elseif shell.alias[name] then
        local aliasPath = fs.combine(_env.PROGS, shell.alias[name])
        if fs.exists(aliasPath) then
            return shell.alias[name]
        end
    end
    return nil, "No such program"
end
function shell.getenv(name)
    checkArg(1,name,"string")
    return _env[name]
end
function shell.setenv(name,value)
    checkArg(1,name,"string")
    value = tostring(value)
    _env[name] = value
end
os.setenv = shell.setenv
os.getenv = shell.getenv
function shell.phrase(command)
    checkArg(1,command,"string")
    -- simply splits by whitespace and substitues all $ to thier respective _env values
    local tokens = {}
    for token in command:gmatch("[%S]+") do
        token = token:gsub("%$(%w+)", function(var)
            return _env[var] or ""
        end)
        table.insert(tokens,token)
    end
    return tokens
end
-- programs are passed shell os they can read and execute other commands and also write to the output if needed but if they return a value autowrite
function shell.run(command,out)
    out = out or shell.outpipe
    local phrased = shell.phrase(command)
    local target = table.remove(phrased, 1)
    local progPath = fs.combine(_env.PROGS, target)

    if fs.exists(progPath) then
        shell.runningProg = progPath
        local ok, err = dofile(progPath, shell, table.unpack(phrased))
        if not ok and err then
            io.stderr:write(("error in command '%s': %s\n"):format(target, err))
            return false
        end
        if ok then
            out:write(ok)
        end
        return true
    elseif shell.alias[target] then
        shell.runningProg = shell.alias[target]
        local aliasPath = fs.combine(_env.PROGS, shell.alias[target])
        if fs.exists(aliasPath) then
            local ok, err = dofile(aliasPath, shell, table.unpack(phrased))
            if not ok and err then
                io.stderr:write(("error in alias '%s': %s\n"):format(target, err))
                return false
            end
            if ok then
                out:write(ok)
            end
            return true
        end
    end

    io.stderr:write(("command not found: %s\n"):format(target))
    return false
end

function shell.execute(...) -- same as shell.run(table.concat({...}," "))
    shell.run(table.concat({...}," "))
end
function shell.executePipe(out,...)
    shell.run(table.concat({...}," "),out)
end
function shell.setalias(cmd,alias)
    shell.alias[alias] = cmd
end
function shell.prompt()
    -- runs a prompt assuming we are on a new line
    io.stdout:write(fs.simplify(_env.CWD).."/@".._env.USER..">")
    local command = term.read()
    shell.run(command)
    --term.newline()
end
local io = require("io")
function io.popen(command)
    local output = {__data={}}
    function output:write(data)
        table.insert(self.__data,data)
    end
    -- execute command
    -- and catch error
    local ok,err = pcall(shell.run,command,output)
    if not ok and err then
        return nil, err
    end
    -- else return pipe contents
    return table.concat(output.__data,"")
end
-- cmdvars used to store session data between commands
function shell.getCmdVars(name)
    if not shell.cmdVars[name] then
        shell.cmdVars[name] = {}
    end
    return shell.cmdVars[name]
end
function shell.setCmdVar(name,key,value)
    shell.getCmdVars(name)[key] = value
end
function shell.getCmdVar(name,key)
    return shell.getCmdVars(name)[key]
end
-- local vars (used in help to cache commands)
function shell.getLocalVars()
    return shell.getCmdVars(shell.runningProg or "GLOBAL")
end
function shell.setLocalVar(key,value)
    shell.getLocalVars()[key] = value
end
function shell.getLocalVar(key)
    return shell.getLocalVars()[key]
end
return shell