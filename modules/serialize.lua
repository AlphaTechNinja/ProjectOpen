local serialize = {}
local json = require("json")
local filesystem = require("filesystem")
serialize.serializeFunction = false

local expr = "%s=%s"

function serialize.serialize(tab, visited)
    if type(visited) == "string" then
        -- check if lua or json
        if visited == "lua" then
            visited = {}
        elseif visited == "json" then
            return json.encode(tab)
        else
            errorf("invalid serialization mode '%s'",visited,2)
        end
    end
    visited = visited or {}
    if visited[tab] then
        error("recursion detected in table serialization", 2)
    end
    visited[tab] = true

    local result = {}
    for n, v in pairs(tab) do
        local key
        if type(n) == "string" and n:match("^%a[%w_]*$") then
            key = n
        else
            key = "[" .. serialize.serialize(n, visited) .. "]"
        end

        local value
        if type(v) == "table" then
            value = serialize.serialize(v, visited)
        elseif type(v) == "string" then
            value = string.format("%q", v)
        elseif type(v) == "function" then
            if serialize.serializeFunction then
                value = "load(" .. string.format("%q", string.dump(v)) .. ")()"
            else
                error("attempted to serialize a function", 2)
            end
        elseif type(v) == "number" then
            if v ~= v then
                value = "0/0" -- NaN
            elseif v == math.huge then
                value = "math.huge"
            elseif v == -math.huge then
                value = "-math.huge"
            else
                value = tostring(v)
            end
        else
            value = tostring(v)
        end

        table.insert(result, expr:format(key, value))
    end

    return "{" .. table.concat(result, ",") .. "}"
end

function serialize.deserialize(str,mode)
    if mode then
        if mode == "json" then
            return json.decode(str)
        elseif mode ~= "lua" then
            errorf("invalid decoding mode '%s'",mode,2)
        end
    end
    local chunk = "return " .. str
    local safeEnv = {
        math = math,
        string = string,
        table = table,
        tonumber = tonumber,
        tostring = tostring,
        type = type,
        pairs = pairs,
        ipairs = ipairs,
        next = next,
        select = select
    }
    if serialize.serializeFunction then
        safeEnv.load = load
    end
    local func, err = load(chunk, "=serialize.deserialize", "t", safeEnv)
    if not func and err then
        error(err, 2)
    end
    return func()
end

function serialize.deserializeFile(path, mode)
    local handle = filesystem.open(path, "r")
    local raw = handle:readAll()
    return serialize.deserialize(raw, mode)
end

return serialize
