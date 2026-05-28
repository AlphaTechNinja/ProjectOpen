local io = require("io")
local term = require("terminal")
local fs = require("filesystem")
local shell = require("shells.simpleshell")

local Stream = {}
Stream.__index = Stream
function Stream:new(initial)
    return setmetatable({ data = initial or "" }, self)
end
function Stream:write(str)
    self.data = self.data .. tostring(str)
end
function Stream:read()
    return self.data
end

local parser = {}
local patterns = {
    STRING = {"%b\"\"", "%b''", "%b``"},
    LEFT_BRACKET = "%(",
    RIGHT_BRACKET = "%)",
    DOLLAR_ARG = "%$%d+",
    DOLLAR_VAR = "%$%w+",
    MULTI = "&&",
    PIPE = "%|",
    BINARY_OP = {"%+", "%-", "%*", "%/"},
    NUMBER = {"(%d+)"},
    WORD = "[%w_%.%-%/~]+"
}

local function tok(t, v) return { type = t, value = v } end
local handlers = {
    STRING = function(s, a, b) return tok("STRING", s:sub(a + 1, b - 1)) end,
    LEFT_BRACKET = function() return tok("LEFT_BRACKET", "(") end,
    RIGHT_BRACKET = function() return tok("RIGHT_BRACKET", ")") end,
    DOLLAR_ARG = function(s, a, b) return tok("ARG", tonumber(s:sub(a + 1, b))) end,
    DOLLAR_VAR = function(s, a, b) return tok("ENVVAR", s:sub(a + 1, b)) end,
    MULTI = function() return tok("MULTI", "&&") end,
    PIPE = function() return tok("PIPE", "|") end,
    BINARY_OP = function(s, a, b) return tok("BINARY_OP", s:sub(a, b)) end,
    NUMBER = function(s, a, b) return tok("NUMBER", tonumber(s:sub(a, b))) end,
    WORD = function(s, a, b) return tok("WORD", s:sub(a, b)) end
}

function parser.findToken(str, i)
    local bs, be, bpat, vals = math.huge, 0, "", {}
    for name, pat in pairs(patterns) do
        local s, e, cur
        if type(pat) == "table" then
            for _, p in ipairs(pat) do
                cur = {string.find(str, p, i)}
                s, e = cur[1], cur[2]
                if s then break end
            end
        else
            cur = {string.find(str, pat, i)}
            s, e = cur[1], cur[2]
        end
        if s and (s < bs or (s == bs and e > be)) then
            bs, be, bpat, vals = s, e, name, cur
        end
    end
    if bs == math.huge then return nil end
    local t = handlers[bpat](str, bs, be, table.unpack(vals))
    t.index = bs
    return t, be + 1
end

function parser.parseString(str)
    local tokens = {}
    local i = 1
    while i <= #str do
        local t, n = parser.findToken(str, i)
        if not t then break end
        tokens[#tokens + 1] = t
        i = n
    end
    return tokens
end

parser.condensers = {}
parser.condensers.BRACKETS = function(tokens)
    while true do
        local stack, found = {}, false
        for i, t in ipairs(tokens) do
            if t.type == "LEFT_BRACKET" then
                table.insert(stack, i)
            elseif t.type == "RIGHT_BRACKET" and #stack > 0 then
                local left = table.remove(stack)
                local inner = {}
                for j = left + 1, i - 1 do inner[#inner + 1] = tokens[j] end
                local group = { type = "EXPRESSION_GROUP", inner = inner, subshell = true }
                local newTokens = {}
                for j = 1, left - 1 do newTokens[#newTokens + 1] = tokens[j] end
                newTokens[#newTokens + 1] = group
                for j = i + 1, #tokens do newTokens[#newTokens + 1] = tokens[j] end
                tokens = newTokens
                found = true
                break
            end
        end
        if not found then break end
    end
    return tokens
end

parser.condensers.BINARY_EXPRESSIONS = function(tokens)
    local function reduceOps(opSet)
        local i = 1
        while i <= #tokens do
            local t = tokens[i]
            if t.type == "BINARY_OP" and opSet[t.value] then
                local left, right = tokens[i - 1], tokens[i + 1]
                if left and right then
                    local expr = { type = "EXPRESSION", op = t.value, left = left, right = right }
                    tokens[i - 1] = expr
                    table.remove(tokens, i)
                    table.remove(tokens, i)
                    i = i - 1
                end
            end
            i = i + 1
        end
    end

    -- precedence: * and / before + and -
    reduceOps({ ["*"] = true, ["/"] = true })
    reduceOps({ ["+"] = true, ["-"] = true })
    return tokens
end

parser.condensers.COMMAND = function(tokens)
    local i = 1
    while i <= #tokens do
        local t = tokens[i]
        if t.type == "WORD" then
            local cmd = { type = "COMMAND", cmd = t.value, args = {} }
            local j = i + 1
            while j <= #tokens do
                local cur = tokens[j]
                if cur.type == "PIPE" or cur.type == "MULTI" then break end
                cmd.args[#cmd.args + 1] = cur
                j = j + 1
            end
            local newTokens = {}
            for k = 1, i - 1 do newTokens[#newTokens + 1] = tokens[k] end
            newTokens[#newTokens + 1] = cmd
            for k = j, #tokens do newTokens[#newTokens + 1] = tokens[k] end
            tokens = newTokens
            i = i + 1
        else
            i = i + 1
        end
    end
    return tokens
end

function parser.condenseTokens(tokens, ...)
    for _, c in ipairs({...}) do tokens = c(tokens) end
    return tokens
end

local function parseNumber(v)
    if type(v) == "number" then return v end
    if type(v) ~= "string" then return nil end
    if v:match("^0x[%da-fA-F]+$") then return tonumber(v) end
    return tonumber(v)
end

local function parseAssignValue(raw)
    local v = raw
    if not v then
        return ""
    end
    v = v:gsub("^%s+", ""):gsub("%s+$", "")
    if #v >= 2 then
        local q1, q2 = v:sub(1, 1), v:sub(-1)
        if (q1 == "\"" and q2 == "\"") or (q1 == "'" and q2 == "'") then
            return v:sub(2, -2)
        end
    end
    if v == "true" then return true end
    if v == "false" then return false end
    local n = parseNumber(v)
    if n ~= nil then return n end
    return v
end

function shell:evalExpression(node, context)
    context = context or { lastOutput = nil, env = self._env, cmdArgs = {} }
    if node.type == "STRING" or node.type == "NUMBER" or node.type == "WORD" then
        return node.value
    elseif node.type == "ENVVAR" then
        return context.env[node.value] or ""
    elseif node.type == "ARG" then
        return context.cmdArgs[node.value] or ""
    elseif node.type == "EXPRESSION_GROUP" then
        local tempOut = Stream:new()
        local oldOut = self.outpipe
        self.outpipe = tempOut
        local inner = parser.condenseTokens(
            node.inner,
            parser.condensers.BINARY_EXPRESSIONS,
            parser.condensers.COMMAND
        )
        local innerRes = self:interpret(inner, context)
        self.outpipe = oldOut
        local out = tempOut:read() or ""
        if out == "" and innerRes ~= nil then
            out = tostring(innerRes)
        end
        context.lastOutput = out
        return out
    elseif node.type == "EXPRESSION" then
        local left = self:evalExpression(node.left, context)
        local right = self:evalExpression(node.right, context)
        local op = node.op
        local lnum = parseNumber(left)
        local rnum = parseNumber(right)
        if op == "+" then
            if lnum and rnum then return lnum + rnum end
            return tostring(left) .. tostring(right)
        elseif op == "-" then
            if lnum and rnum then return lnum - rnum end
            error("Invalid operands for -", 2)
        elseif op == "*" then
            if lnum and rnum then return lnum * rnum end
            error("Invalid operands for *", 2)
        elseif op == "/" then
            if lnum and rnum then return lnum / rnum end
            error("Invalid operands for /", 2)
        end
    elseif node.type == "COMMAND" then
        local evaluatedArgs = {}
        local cmdArgs = {}
        for _, arg in ipairs(node.args) do
            local val = self:evalExpression(arg, { cmdArgs = {}, lastOutput = context.lastOutput, env = context.env })
            evaluatedArgs[#evaluatedArgs + 1] = val
            cmdArgs[#cmdArgs + 1] = val
        end
        context.cmdArgs = cmdArgs
        local commandLine = node.cmd
        if #evaluatedArgs > 0 then
            commandLine = commandLine .. " " .. table.concat(evaluatedArgs, " ")
        end
        local output = { __data = {} }
        function output:write(d) self.__data[#self.__data + 1] = d end
        local ok = self:run(commandLine, output)
        if not ok then
            return nil
        end
        local text = table.concat(output.__data, "")
        context.lastOutput = text
        return text
    end
end

function shell:interpret(ast, context, ...)
    context = context or { lastOutput = nil, env = self._env, cmdArgs = {...} }
    local first
    for _, node in ipairs(ast) do
        local res = self:evalExpression(node, context)
        first = first or res
    end
    return context.lastOutput or first
end

function shell:runAdvanced(cmd, out, ...)
    out = out or self.outpipe
    local assignName, assignValueRaw = cmd:match("^%s*%$([%a_][%w_]*)%s*=%s*(.-)%s*$")
    if assignName then
        local current = self:getenv(assignName)
        if type(current) == "table" and not current.__shellset then
            io.stderr:write(("env var '$%s' is read-only\n"):format(assignName))
            return nil
        end
        local value = parseAssignValue(assignValueRaw)
        self:setenv(assignName, value)
        return value
    end
    local tokens = parser.condenseTokens(
        parser.parseString(cmd),
        parser.condensers.BRACKETS,
        parser.condensers.BINARY_EXPRESSIONS,
        parser.condensers.COMMAND
    )
    local res = self:interpret(tokens, nil, ...)
    if res and tostring(res) ~= "" then out:write(res) end
    return res
end

function io.popen(cmd)
    local pipe = Stream:new()
    local ok, err = pcall(function() shell:runAdvanced(cmd, pipe) end)
    if not ok then return nil, err end
    return pipe:read()
end

function shell:prompt()
    io.stdout:write(fs.simplify(self._env.CWD) .. "/@" .. self:getPromptUser() .. ">")
    local input = term.read()
    if not input or input:match("^%s*$") then
        return
    end
    local ok, err = pcall(function()
        self:runAdvanced(input)
    end)
    if not ok then
        io.stderr:write("Error: " .. tostring(err) .. "\n")
    end
end

return shell
