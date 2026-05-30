local args = {...}
local shell = table.remove(args, 1)
local editor = kernel.package.import("ProjectOpenEditor", { scope = "global" })

local t1 = editor.newToken("word", "hello", 1)
local t2 = editor.newToken("word", "world", 7)
local prog = editor.newProgram("hello world", { t1, t2 })

prog:insertAt(6, " beautiful")

local lines = {
    "buffer=" .. prog.buffer,
    "t1=" .. tostring(t1.contents) .. "@" .. tostring(t1.location),
    "t2=" .. tostring(t2.contents) .. "@" .. tostring(t2.location),
    "dirty=" .. tostring(prog.dirty)
}

return table.concat(lines, "\n") .. "\n"
