local classes = require("classes")

local Tokenizer = package.import("./tokenizer", { scope = "local" })
local Pattern = package.import("./pattern", { scope = "local" })
local PatternCollection = package.import("./patternCollection", { scope = "local" })
local Token = package.import("./token", { scope = "local" })

local Lang = classes.create("ProjectOpenEditorLang")

local function trim(str)
    return (str:gsub("^%s+", ""):gsub("%s+$", ""))
end

local function isComment(line)
    return line:match("^%s*#") or line:match("^%s*//") or line:match("^%s*%-%-")
end

local function splitPatternAndPriority(rest)
    local pattern, priority = rest:match("^(.-),%s*([%+%-]?%d+)%s*$")
    if pattern then
        return trim(pattern), tonumber(priority)
    end
    return trim(rest), nil
end

function Lang:constructor(source)
    return setmetatable({
        source = tostring(source or ""),
        lines = {}
    }, self)
end

function Lang:load(source)
    self.source = tostring(source or self.source or "")
    self.lines = {}

    for raw in self.source:gmatch("[^\r\n]+") do
        local line = trim(raw)
        if line ~= "" and not isComment(line) then
            local kind, rest = line:match("^([%w_]+)%s*:%s*(.+)$")
            if not kind then
                error(("invalid lang line '%s'"):format(raw), 2)
            end

            local pattern, priority = splitPatternAndPriority(rest)
            if pattern == "" then
                error(("missing pattern for lang line '%s'"):format(raw), 2)
            end

            self.lines[#self.lines + 1] = {
                kind = kind,
                pattern = pattern,
                priority = priority or 0
            }
        end
    end

    return self
end

function Lang:toCollection(converterFactory)
    local collection = PatternCollection:new()

    for i = 1, #self.lines do
        local spec = self.lines[i]
        local converter
        if converterFactory then
            converter = converterFactory(spec.kind, spec.pattern, spec.priority, i)
        end

        if not converter then
            converter = function(match)
                local text = match.text:sub(match.start, match.finish)
                return {
                    token = Token:new(spec.kind, text, match.start),
                    next = match.finish + 1
                }
            end
        end

        collection:add(Pattern:new(spec.pattern, converter, spec.kind), spec.priority)
    end

    return collection
end

function Lang:toTokenizer(converterFactory, options)
    return Tokenizer:new(self:toCollection(converterFactory), options)
end

function Lang:__tostring()
    return self.source
end

return Lang
