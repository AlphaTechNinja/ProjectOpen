local args = {...}
local shell = table.remove(args,1)
return table.concat(args," ").."\n"