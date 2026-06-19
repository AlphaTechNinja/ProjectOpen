local classes = require("classes")

local Token = package.import("./token", { scope = "local" })
local PatternCollection = package.import("./patternCollection", { scope = "local" })

local Tokenizer = classes.create("ProjectOpenEditorTokenizer")

local function mergeOptions(base, extra)
    local out = {}
    if base then
        for k, v in pairs(base) do
            out[k] = v
        end
    end
    if extra then
        for k, v in pairs(extra) do
            out[k] = v
        end
    end
    return out
end

local function isProgram(value)
    return type(value) == "table" and value.buffer ~= nil and value.tokens ~= nil
end

function Tokenizer:constructor(collection, options)
    if collection and type(collection) == "table" and not collection.match and collection.toCollection then
        collection = collection:toCollection(options and options.converterFactory)
    end

    if collection and type(collection) ~= "table" then
        error("pattern collection expected", 2)
    end

    return setmetatable({
        collection = collection or PatternCollection:new(),
        options = options or {}
    }, self)
end

function Tokenizer:setCollection(collection)
    assert(type(collection) == "table", "pattern collection expected")
    self.collection = collection
    return self
end

function Tokenizer:setOptions(options)
    self.options = options or {}
    return self
end

function Tokenizer:tokenizeText(text, options)
    assert(type(text) == "string", "text expected")
    local opts = mergeOptions(self.options, options)
    local collection = self.collection or PatternCollection:new()
    local tokens = {}
    local pos = math.max(1, tonumber(opts.start) or 1)

    while pos <= #text do
        local best = collection:match(text, pos)
        if best then
            local token = best.token
            if token then
                token.location = token.location or best.start or pos
                if token.location ~= (best.start or token.location) then
                    token.location = best.start or token.location
                end
            end
            if not token then
                token = Token:new(opts.unknownKind or "unknown", text:sub(best.start, best.finish), best.start)
            end
            tokens[#tokens + 1] = token

            local nextPos = best.result and best.result.next or (best.finish + 1)
            if not nextPos or nextPos <= pos then
                nextPos = (best.finish or pos) + 1
            end
            pos = nextPos
        else
            if opts.consumeUnknown == false then
                break
            end
            local unknownText = text:sub(pos, pos)
            tokens[#tokens + 1] = Token:new(opts.unknownKind or "unknown", unknownText, pos)
            pos = pos + 1
        end
    end

    return tokens
end

function Tokenizer:tokenizeProgram(program, options)
    assert(isProgram(program), "program expected")
    program.tokens = self:tokenizeText(program.buffer or "", options)
    if program.markDirty then
        program:markDirty(true)
    else
        program.dirty = true
    end
    return program
end

function Tokenizer:tokenize(value, options)
    if isProgram(value) then
        return self:tokenizeProgram(value, options)
    end
    return self:tokenizeText(value, options)
end

function Tokenizer:scan(text, options)
    return self:tokenizeText(text, options)
end

return Tokenizer
