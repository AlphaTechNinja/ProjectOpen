local classes = require("classes")

local PatternCollection = classes.create("ProjectOpenEditorPatternCollection")

local function cloneList(list)
    local out = {}
    for i = 1, #list do
        out[i] = list[i]
    end
    return out
end

local function sortPatterns(patterns)
    table.sort(patterns, function(a, b)
        local ap = a.priority or 0
        local bp = b.priority or 0
        if ap == bp then
            return (a.order or 0) < (b.order or 0)
        end
        return ap > bp
    end)
end

function PatternCollection:constructor(patterns)
    return setmetatable({
        patterns = cloneList(patterns or {}),
        dirty = true
    }, self)
end

function PatternCollection:add(pattern, priority)
    assert(type(pattern) == "table", "pattern expected")
    pattern.priority = priority or pattern.priority or 0
    pattern.order = #self.patterns + 1
    self.patterns[#self.patterns + 1] = pattern
    self.dirty = true
    return pattern
end

function PatternCollection:remove(pattern)
    for i = 1, #self.patterns do
        if self.patterns[i] == pattern then
            table.remove(self.patterns, i)
            self.dirty = true
            return true
        end
    end
    return false
end

function PatternCollection:clear()
    self.patterns = {}
    self.dirty = true
end

function PatternCollection:sort()
    sortPatterns(self.patterns)
    self.dirty = false
    return self
end

function PatternCollection:getPatterns()
    if self.dirty then
        self:sort()
    end
    return self.patterns
end

function PatternCollection:match(text, init)
    assert(type(text) == "string", "text expected")
    init = init or 1

    local best = nil
    local patterns = self:getPatterns()
    for i = 1, #patterns do
        local pattern = patterns[i]
        local result = pattern:match(text, init)
        if result then
            local candidate = result.token or result
            local start = result.start or candidate.location or init
            local finish = result.finish or candidate:getEnd() or start

            if not best
                or start < best.start
                or (start == best.start and (pattern.priority or 0) > (best.priority or 0))
                or (start == best.start and (pattern.priority or 0) == (best.priority or 0) and finish < best.finish)
            then
                best = {
                    pattern = pattern,
                    result = result,
                    token = candidate,
                    start = start,
                    finish = finish,
                    priority = pattern.priority or 0
                }
            end
        end
    end

    return best
end

function PatternCollection:scan(text, init)
    assert(type(text) == "string", "text expected")
    init = init or 1

    local tokens = {}
    local pos = init
    while pos <= #text do
        local best = self:match(text, pos)
        if not best then
            break
        end
        tokens[#tokens + 1] = best.token
        pos = best.result.next or (best.finish + 1)
    end
    return tokens
end

function PatternCollection:__len()
    return #self.patterns
end

return PatternCollection
