-- =======================================
-- AST-Based Shell Interpreter with $args
-- =======================================
local io = require("io")
local fs = require("filesystem")
local term = require("terminal")

-- ===============================
-- Simple string stream
-- ===============================
local Stream = {}
Stream.__index = Stream

function Stream:new(initial)
    return setmetatable({data = initial or ""}, self)
end

function Stream:write(str)
    self.data = self.data .. tostring(str)
end

function Stream:read()
    return self.data
end

-- ===============================
-- Shell table
-- ===============================
local shell = {}
shell._env = {
    CWD = "/home/",
    HOME = "/home/",
    USER = "root",
    PROGS = "/bin/",
    NONE = ""
}
shell.alias = {}
shell.cmdVars = { GLOBAL = _G }
shell.outpipe = io.stdout
shell.runningProg = nil

-- ===============================
-- Environment helpers
-- ===============================
function shell.getenv(name)
    return shell._env[name]
end
function shell.setenv(name,value)
    shell._env[name] = tostring(value)
end

-- ===============================
-- Command variable helpers
-- ===============================
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
function shell.getLocalVars()
    return shell.getCmdVars(shell.runningProg or "GLOBAL")
end
function shell.setLocalVar(key,value)
    shell.getLocalVars()[key] = value
end
function shell.getLocalVar(key)
    return shell.getLocalVars()[key]
end

-- ===============================
-- Resolve paths and programs
-- ===============================
function shell.resolve(path)
    if path:sub(1,1) == "/" then return path end
    return fs.simplify(fs.combine(shell._env.CWD,path))
end

function shell.resolveProgram(name)
    local progPath = fs.combine(shell._env.PROGS, name)
    if fs.exists(progPath) then return progPath end
    if shell.alias[name] then
        local aliasPath = fs.combine(shell._env.PROGS, shell.alias[name])
        if fs.exists(aliasPath) then return aliasPath end
    end
    return nil
end

function shell.setalias(cmd,alias)
    shell.alias[alias] = cmd
end

-- ===============================
-- Run a command (fixed for AST output)
-- ===============================
function shell.run(cmdName, out, ...)
    out = out or shell.outpipe
    local args = {...}
    local target = cmdName
    local progPath = fs.combine(shell._env.PROGS, target)

    local function runPath(path)
        local chunk, err = loadfile(path)
        if not chunk then
            io.stderr:write(("Failed to load '%s': %s\n"):format(target, err))
            return false, ""
        end

        shell.runningProg = path

        -- Always prepend shell
        table.insert(args, 1, shell)

        -- Call the command chunk
        local ok, result = pcall(chunk, table.unpack(args))
        if not ok then
            io.stderr:write(("error in command '%s': %s\n"):format(target, result))
            return false, ""
        end

        -- Capture return value if any
        local output = ""
        if result ~= nil then
            output = tostring(result)
            out:write(output)
        end

        return true, output
    end

    if fs.exists(progPath) then
        return runPath(progPath)
    elseif shell.alias[target] then
        local aliasPath = fs.combine(shell._env.PROGS, shell.alias[target])
        if fs.exists(aliasPath) then
            return runPath(aliasPath)
        end
    end

    io.stderr:write(("command not found: %s\n"):format(target))
    return false, ""
end


-- ===============================
-- Tokenizer / parser
-- ===============================
local praser = {}
local patterns = {
    STRING = {"%b\"\"","%b''","%b``"},
    LEFT_BRACKET = "%(",
    RIGHT_BRACKET = "%)",
    DOLLAR_ARG = "%$%d+",
    DOLLAR_VAR = "%$%w+",
    MULTI = "&&",
    PIPE = "|",
    BINARY_OP = {"%+","%-","%*","%/"},
    NUMBER = {"(%d+)"},
    WORD = "%w+"
}

local function mh(type,value) return { type=type, value=value } end

local handlers = {
    STRING = function(s,a,b) return mh("STRING", s:sub(a+1,b-1)) end,
    LEFT_BRACKET = function() return mh("LEFT_BRACKET","(") end,
    RIGHT_BRACKET = function() return mh("RIGHT_BRACKET",")") end,
    DOLLAR_ARG = function(s,a,b) return mh("ARG", tonumber(s:sub(a+2,b))) end,
    DOLLAR_VAR = function(s,a,b) return mh("ENVVAR", s:sub(a+2,b)) end,
    MULTI = function() return mh("MULTI","&&") end,
    PIPE = function() return mh("PIPE","|") end,
    BINARY_OP = function(s,a,b,...) return mh("BINARY_OP",s:sub(a,b)) end,
    NUMBER = function (s,a,b,...) return mh("NUMBER",tonumber(s:sub(a,b))) end,
    WORD = function(s,a,b,...) return mh("WORD",s:sub(a,b)) end
}

function praser.findToken(str,i)
    local bs,be,bpat,vals = math.huge,0,"",{}
    for name,pat in pairs(patterns) do
        local s,e,cur
        if type(pat)=="table" then
            for _,p in ipairs(pat) do
                cur={string.find(str,p,i)}
                s,e = cur[1],cur[2]
                if s then break end
            end
        else
            cur={string.find(str,pat,i)}
            s,e = cur[1],cur[2]
        end
        if s and (s<bs or (s==bs and e>be)) then
            bs,be,bpat,vals = s,e,name,cur
        end
    end
    if bs==math.huge then return nil end
    local token = handlers[bpat](str,bs,be,table.unpack(vals))
    token.index = bs
    return token, be+1
end

function praser.parseString(str)
    local tokens = {}
    local i=1
    while i<=#str do
        local token,n = praser.findToken(str,i)
        if not token then break end
        tokens[#tokens+1] = token
        i = n
    end
    return tokens
end

-- ===============================
-- Condensers
-- ===============================
praser.condensers = {}

praser.condensers.BRACKETS = function(tokens)
    while true do
        local stack,found = {},false
        for i,t in ipairs(tokens) do
            if t.type=="LEFT_BRACKET" then table.insert(stack,i)
            elseif t.type=="RIGHT_BRACKET" and #stack>0 then
                local left = table.remove(stack)
                local right = i
                local inner={}
                for j=left+1,right-1 do table.insert(inner,tokens[j]) end
                local group={ type="EXPRESSION_GROUP", inner=inner, subshell=true }
                local newTokens={}
                for j=1,left-1 do table.insert(newTokens,tokens[j]) end
                table.insert(newTokens,group)
                for j=right+1,#tokens do table.insert(newTokens,tokens[j]) end
                tokens=newTokens
                found=true
                break
            end
        end
        if not found then break end
    end
    return tokens
end

praser.condensers.BINARY_EXPRESSIONS = function(tokens)
    local i=1
    while i<=#tokens do
        local t=tokens[i]
        if t.type=="BINARY_OP" then
            local left,right = tokens[i-1],tokens[i+1]
            if left and right then
                local expr={ type="EXPRESSION", op=t.value, left=left, right=right }
                tokens[i-1]=expr
                table.remove(tokens,i)
                table.remove(tokens,i)
                i=i-1
            end
        end
        i=i+1
    end
    return tokens
end

praser.condensers.COMMAND = function(tokens)
    local i=1
    while i<=#tokens do
        local t=tokens[i]
        if t.type=="WORD" then
            local cmd={ type="COMMAND", cmd=t.value, args={} }
            local j=i+1
            while j<=#tokens do
                local cur = tokens[j]
                if cur.type=="PIPE" or cur.type=="MULTI" then break end
                table.insert(cmd.args,cur)
                j=j+1
            end
            local newTokens={}
            for k=1,i-1 do table.insert(newTokens,tokens[k]) end
            table.insert(newTokens,cmd)
            for k=j,#tokens do table.insert(newTokens,tokens[k]) end
            tokens=newTokens
            i=i+1
        else
            i=i+1
        end
    end
    return tokens
end

function praser.condenseTokens(tokens,...)
    for _,c in ipairs({...}) do tokens=c(tokens) end
    return tokens
end

-- ===============================
-- AST Evaluation Helpers
-- ===============================
local function parseNumber(val)
    if type(val)=="number" then return val end
    if type(val)~="string" then return nil end
    if val:match("^0x[%da-fA-F]+$") then return tonumber(val) end
    return tonumber(val)
end

-- ===============================
-- Evaluate AST
-- ===============================
shell.evalExpression = function(node,context)
    context = context or { lastOutput=nil, env=shell._env, cmdArgs={} }

    if node.type=="STRING" or node.type=="NUMBER" then
        return node.value
    elseif node.type=="ENVVAR" then
        return context.env[node.value] or ""
    elseif node.type=="ARG" then
        return context.cmdArgs[node.value] or ""
    elseif node.type=="EXPRESSION_GROUP" then
        local tempOut = Stream:new()
        local oldOut = shell.outpipe
        shell.outpipe = tempOut
        shell.interpret(node.inner,context)
        shell.outpipe = oldOut
        local out = tempOut:read() or ""
        context.lastOutput = out
        return out
    elseif node.type=="NUMBER" then
        return node.value
    elseif node.type=="EXPRESSION" then
        local left = shell.evalExpression(node.left,context)
        local right = shell.evalExpression(node.right,context)
        local op = node.op
        local lnum = parseNumber(left)
        local rnum = parseNumber(right)
        if op=="+" then
            if lnum and rnum then return lnum+rnum end
            return tostring(left)..tostring(right)
        elseif op=="-" then
            if lnum and rnum then return lnum-rnum end
            error("Invalid operands for -: "..tostring(left).." - "..tostring(right))
        elseif op=="*" then
            if lnum and rnum then return lnum*rnum end
            error("Invalid operands for *: "..tostring(left).." * "..tostring(right))
        elseif op=="/" then
            if lnum and rnum then return lnum/rnum end
            error("Invalid operands for /: "..tostring(left).." / "..tostring(right))
        end
    elseif node.type=="COMMAND" then
    local evaluatedArgs = {}
    local cmdArgs = {}
    for i,arg in ipairs(node.args) do
        local val = arg.eval and shell.evalExpression(arg,{cmdArgs={}, lastOutput=context.lastOutput, env=context.env}) or (arg.value or "")
        table.insert(evaluatedArgs, val)
        table.insert(cmdArgs, val)
    end
    context.cmdArgs = cmdArgs

    -- prepend shell as first argument
    table.insert(evaluatedArgs, 1, shell)

    -- if there’s a pipe, insert lastOutput after shell
    if node.insertPipe then
        table.insert(evaluatedArgs, 2, context.lastOutput)
        context.lastOutput = nil
    end

    -- run the command
    local ok, ok2, result = pcall(shell.run, node.cmd, nil, table.unpack(evaluatedArgs))
    if not ok or not ok2 then io.stderr:write("Error executing command: "..tostring(result).."\n") end
    context.lastOutput = result
    --io.stdout:write(result)
    return result

end
end

-- ===============================
-- Interpret AST
-- ===============================
shell.interpret = function(ast,context,...)
    context = context or { lastOutput=nil, env=shell._env, cmdArgs={...} }
    local first
    for _,node in ipairs(ast) do
        local res = shell.evalExpression(node,context)
        first = first or res
    end
    return context.lastOutput or first
end

-- ===============================
-- Run advanced command string
-- ===============================
shell.runAdvanced = function(cmd,out,...)
    out = out or shell.outpipe
    local tokens = praser.condenseTokens(
        praser.parseString(cmd),
        praser.condensers.BRACKETS,
        praser.condensers.BINARY_EXPRESSIONS,
        praser.condensers.COMMAND
    )
    local res = shell.interpret(tokens,nil,...)
    if res then out:write(res) end
end

-- ===============================
-- io.popen override
-- ===============================
io.popen = function(cmd)
    local pipe = Stream:new()
    local ok, err = pcall(shell.runAdvanced, cmd, pipe)
    if not ok then return nil, err end
    return pipe:read()
end

-- ===============================
-- Interactive prompt
-- ===============================
function shell.prompt()
    while true do
        io.stdout:write(shell._env.CWD .. "/@" .. shell._env.USER .. "> ")
        local input = term.read()
        if not input or input:match("^%s*$") then
            -- skip empty input
        elseif input:lower() == "exit" then
            break
        else
            local tokens = praser.parseString(input)
            tokens = praser.condenseTokens(tokens,
                praser.condensers.BRACKETS,
                praser.condensers.BINARY_EXPRESSIONS,
                praser.condensers.COMMAND
            )
            local ok, err = pcall(shell.interpret, tokens)
            if not ok then
                io.stderr:write("Error: "..tostring(err).."\n")
            elseif err and #err > 0 then
                --io.stdout:write(err)
            end
            io.stdout:write("\n")
        end
    end
end

-- ===============================
-- Expose shell
-- ===============================
praser.shell = shell
return praser
