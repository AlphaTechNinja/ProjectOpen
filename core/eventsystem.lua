local poll = require("poll")
local classes = require("classes")

---@alias EventHandle (fun(... : any) : any) | thread<(fun(... : any) : any)>

---@class EventSystem : classes
---@field __handles table<string, EventHandle[]>
local EventSystem = classes.create("EventSystem")

function EventSystem:constructor()
    local o = setmetatable({},self)
    ---@cast o EventSystem
    o.__handles = {}
    return o
end

--- Invoke event
---@param name string
---@param ... any
function EventSystem:invoke(name, ...)
    local handles = self.__handles[name]
    if handles then
        for i=1, #handles do
            local handle = handles[i]
            if type(handle) == "function" then
                handle(...)
            elseif type(handle) == "thread" then
                poll.resumeLocked(handle, "silent", nil, ...)
            end
        end
    end
end

--- Register handle
---@param name string
---@param callback EventHandle
function EventSystem:on(name, callback)
    local handles = self.__handles[name] or {}
    self.__handles[name] = handles

    handles[#handles+1] = callback
end

--- Remove handle
---@param name string
---@param callback EventHandle
function EventSystem:remove(name, callback)
    local handles = self.__handles[name] or {}
    for i=1, #handles do
        if handles[i] == callback then
            table.remove(handles, i)
            return
        end
    end
end

return EventSystem