local args = {...}
local shell = table.remove(args, 1)
local fs = kernel.filesystem

if #args == 0 then
    errorf("Usage:cd <path>", 2)
end
local newpath = fs.resolve(args[1])
if not fs.exists(newpath) then
    errorf("Directory at '%s' does not exists",newpath,2)
end
if not fs.isDirectory(newpath) then
    errorf("the target path is not a directory '%s'",newpath,2)
end
shell.setenv("CWD",newpath)
return ""