local args = {...}
local shell = table.remove(args,1)
local fs = kernel.filesystem
local localVars = shell.getLocalVars()
if shell.getenv("PROGS") ~= localVars.lastProgs then
    localVars.lastProgs = shell.getenv("PROGS")
    localVars.cache = {}
end
-- check for -a
if args[1] == "-a" then
    local list = fs.list(fs.combine(shell.getenv("PROGS"), ".info"))
    return table.concat(list,"\n").."\n"
end
-- check if the command exists
-- by checking bin/prog
local progpath,err = shell.resolveProgram(args[1])
if not progpath and err then
    errorf("command '%s' doesn't exists",args[1],2)
end
-- check if manual is cached
-- also help info will always be in $PROGS/.info/<NAME>
local helppath = fs.combine(shell.getenv("PROGS"),".info",shell.resolveProgramName(args[1]))
if not fs.exists(helppath) then
    return ("command '%s' has no help info\n"):format(args[1]) -- no need to error
end
-- check if we have this info cached finally
if localVars.cache[helppath] then
    return localVars.cache[helppath]
end
-- if not load info
local info,err = dofile(helppath)
if not info and err then
    errorf("invalid help info for '%s'",helppath,2)
end
-- now extract help field
if not info.help then
    return ("command '%s' has no help info\n"):format(args[1]) -- aw man no help
end
-- cache and return
localVars.cache[helppath] = args[1]..": \n"..info.help.."\n"
return args[1]..": \n"..info.help.."\n"