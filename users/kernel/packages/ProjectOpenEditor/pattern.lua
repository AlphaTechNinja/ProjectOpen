local classes = require("classes")

local Pattern = classes.create("ProjectOpenEditorPattern")

function Pattern:constructor(pattern, converter, kind)
    assert(type(pattern) == "string", "pattern string expected")
    assert(type(converter) == "function", "converter function expected")
    return setmetatable({
        pattern = pattern,
        converter = converter,
        kind = kind or "pattern"
    }, self)
end

function Pattern:match(text, init)
    assert(type(text) == "string", "text expected")
    init = init or 1

    local found = { string.find(text, self.pattern, init) }
    local s, e = found[1], found[2]
    if not s then
        return nil
    end
    local captures = {}
    for i = 3, #found do
        captures[#captures + 1] = found[i]
    end

    return self.converter({
        text = text,
        start = s,
        finish = e,
        captures = captures,
        pattern = self.pattern,
        kind = self.kind
    })
end

function Pattern:scan(text, init)
    assert(type(text) == "string", "text expected")
    init = init or 1

    local tokens = {}
    local pos = init
    while pos <= #text do
        local result = self:match(text, pos)
        if not result then
            break
        end
        tokens[#tokens + 1] = result.token or result
        pos = result.next or (result.finish and (result.finish + 1) or (#text + 1))
    end
    return tokens
end

return Pattern
