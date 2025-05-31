local args = {...}
local shell = table.remove(args, 1)
local fs = kernel.filesystem

if #args == 0 then
    errorf("Usage: cat <file1> [file2 ...]", 2)
end

local output = {}

for _, file in ipairs(args) do
    local resolved = shell.resolve(file)

    if not fs.exists(resolved) then
        errorf("File not found: '%s'", resolved, 2)
    end

    local fh = fs.open(resolved, "r")
    table.insert(output, fh:readAll())
    fh:close()
end

return table.concat(output, "\n").."\n"
