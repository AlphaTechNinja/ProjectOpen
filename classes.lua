--my latest version of classes
local classes = {}
classes.__index = classes
function classes.create(name,...)
    local args = {...}
    if #args > 1 then
        local multi = {parents = args}
        function multi.__index(k)
            if classes[k] then
                return classes[k]
            end
            for i,p in ipairs(multi.parents) do
                if p[k] then
                    return p[k]
                end
            end
        end
        multi.__call = classes.__call
        local class = {}
        class.__name = name
        class.__index = class
        return setmetatable(class,multi)
    elseif #args == 1 then
        local class = {}
        class.__name = name
        class.__index = class
        return setmetatable(class,args[1])
    else
        local class = {}
        class.__name = name
        class.__index = class
        return setmetatable(class,classes)
    end
end
function classes.new(self,...)
    if self.constructor then
        return self:constructor(...)
    else
        return setmetatable({...},self)
    end
end
function classes:__call(...)
    return self:new(...)
end
function classes:isOf(other)
    if type(other) ~= "table" then
        return false
    end
    if getmetatable(self) == classes then
        return false
    elseif getmetatable(self) == other then
        return true
    elseif getmetatable(self):isOf(other) then
        return true
    elseif getmetatable(self).parents then
        for _,p in ipairs(getmetatable(self).parents) do
            if p == other then return true end
        end
    end
end
-- OpenComputers special (at some point)
--[[
local checkArg = checkArg
function classes.checkArg(index,arg,types)
    checkArg(1,index,"number")
    checkArg(3,types,{"table","string"})
    if type(types) == "table" then
        for _,v in ipairs(types) do
            assert(type(v) == "string" or type(v) == "table","Invalid checkArg type")
            if type(v) == "table" then
                -- check class
            else
                checkArg(index,arg,v)
            end
        end
    end
end
--]]
return classes