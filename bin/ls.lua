local args = {...}
local shell = table.remove(args, 1)
local fs = kernel.filesystem
local resolved = shell.resolve(args[1] or "")

-- check if directory exists
if not fs.exists(resolved) then
    errorf("Directory at '%s' does not exists",resolved,2)
end
if not fs.isDirectory(resolved) then
    errorf("the target path is not a directory '%s'",resolved,2)
end
local items = fs.list(resolved)
-- now list and join by newlines
return table.concat(items,"\n").."\n"