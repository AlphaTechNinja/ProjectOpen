local args = {...}
local shell = table.remove(args, 1)
local editor = kernel.package.import("ProjectOpenEditor", { scope = "global" })

local spec = [[
WORD: %a+, 5
NUMBER: %d+, 10
SPACE: %s+, 1
]]

local tokenizer = editor.loadTokenizer(spec, function(kind, pattern, priority)
    return function(match)
        local text = match.text:sub(match.start, match.finish)
        return {
            token = editor.newToken(kind, text, match.start),
            next = match.finish + 1
        }
    end
end)

local program = editor.newProgram("abc 123")
tokenizer:tokenizeProgram(program)

local out = {
    "buffer=" .. program.buffer,
    "dirty=" .. tostring(program.dirty)
}
for i = 1, #program.tokens do
    local token = program.tokens[i]
    out[#out + 1] = (token.type .. ":" .. token.contents .. "@" .. tostring(token.location))
end
return table.concat(out, "\n") .. "\n"
