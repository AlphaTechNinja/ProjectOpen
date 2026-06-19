local Token = package.import("./token", { scope = "local" })
local Program = package.import("./program", { scope = "local" })
local Pattern = package.import("./pattern", { scope = "local" })
local PatternCollection = package.import("./patternCollection", { scope = "local" })
local Tokenizer = package.import("./tokenizer", { scope = "local" })
local Lang = package.import("./lang", { scope = "local" })

local editor = {
    Token = Token,
    Program = Program,
    Pattern = Pattern,
    PatternCollection = PatternCollection,
    Tokenizer = Tokenizer,
    Lang = Lang
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

function editor.newTokenizer(collection, options)
    return Tokenizer:new(collection, options)
end

function editor.newLang(source)
    return Lang:new(source)
end

function editor.loadLang(source, converterFactory)
    local lang = Lang:new(source)
    lang:load(source)
    return lang:toCollection(converterFactory)
end

function editor.loadTokenizer(source, converterFactory, options)
    local lang = Lang:new(source)
    lang:load(source)
    return lang:toTokenizer(converterFactory, options)
end

return editor
