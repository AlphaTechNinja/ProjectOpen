local Token = package.import("./token", { scope = "local" })
local Program = package.import("./program", { scope = "local" })
local Pattern = package.import("./pattern", { scope = "local" })
local PatternCollection = package.import("./patternCollection", { scope = "local" })

local editor = {
    Token = Token,
    Program = Program,
    Pattern = Pattern,
    PatternCollection = PatternCollection
}

function editor.newToken(kind, contents, location, dirty)
    return Token:new(kind, contents, location, dirty)
end

function editor.newProgram(buffer, tokens)
    return Program:new(buffer, tokens)
end

function editor.newPattern(pattern, converter, kind)
    return Pattern:new(pattern, converter, kind)
end

function editor.newPatternCollection(patterns)
    return PatternCollection:new(patterns)
end

return editor
