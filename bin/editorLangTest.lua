local args = {...}
local shell = table.remove(args, 1)
local editor = kernel.package.import("ProjectOpenEditor", { scope = "global" })

local spec = [[
# editor lang smoke test
WORD: %a+, 5
NUMBER: %d+, 10
SPACE: %s+, 1
]]

local collection = editor.loadLang(spec, function(kind, pattern, priority)
    return function(match)
        local text = match.text:sub(match.start, match.finish)
        return {
            token = editor.newToken(kind, text, match.start),
            next = match.finish + 1
        }
    end
end)

local tokens = collection:scan("abc 123")
local out = {}
for i = 1, #tokens do
    out[#out + 1] = (tokens[i].type .. ":" .. tokens[i].contents .. "@" .. tostring(tokens[i].location))
end
return table.concat(out, "\n") .. "\n"
