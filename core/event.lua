-- event system
local classes = require("classes")
local io = require("io")
local Listener = classes.create("Listener")
local event = {}
event.__listeners = {any={}}
local function addListener(listener)
    if event.__listeners[listener.name] then
        table.insert(event.__listeners[listener.name],listener)
    else
        event.__listeners[listener.name] = {listener}
    end
end
function Listener:constructor(name,callback,trace)
    local listener = {name=name or "any",callback=callback,trace=trace or debug.traceback("", 3)}
    addListener(listener)
    return setmetatable(listener,self)
end
-- redirect call to callback in listener (mostly for manual triggering)
function Listener:__call(...)
    if not self.callback then
        error("attempted to call an empty callback",2)
    end
    return self.callback(...)
end
-- poller function
function event.poll(name,...)
    local toremove = {}
    if event.__listeners[name] then
        for i,listener in ipairs(event.__listeners[name]) do
            local ok,err = pcall(listener.callback,...)
            if not ok and err then
                io.stderr:write(("error in listener '%s' defined in '%s':%s"):format(name,listener.trace,err))
                -- faulty listener delete
                table.insert(toremove,listener)
            end
        end
    end
    for i,listener in ipairs(event.__listeners.any) do
        local ok,err = pcall(listener.callback,name,...)
        if not ok and err then
            io.stderr:write(("error in listener Any defined in '%s' passed event '%s':%s"):format(listener.trace,err,name))
            -- faulty listener delete
            table.insert(toremove,listener)
        end
    end
    for _,listener in ipairs(toremove) do
        listener:remove()
    end
end
function event.wait(time)
    time = time or 0.05
    if time < 0.05 then
        return -- too small to wait
    end
    local deadline = computer.uptime() + time
    while computer.uptime() < deadline do
        event.poll(computer.pullSignal(deadline-computer.uptime()))
    end
    return computer.uptime() - deadline
end
function event.pullsignal(name,timeout)
    timeout = timeout or math.huge
    name = name or "any"
    if name == "any" then
        -- just pullsignal
        local evnt = {computer.pullSignal(timeout)}
        event.poll(table.unpack(evnt))
        return table.unpack(evnt)
    else
        -- we actually have to handle event checking
        local deadline = computer.uptime() + timeout
        while computer.uptime() < deadline  do
            local evnt = {computer.pullSignal(timeout)}
            event.poll(table.unpack(evnt))
            if evnt[1] == name then
                return table.unpack(evnt,2)
            end
        end
        -- just let it return nil
    end
end
-- listeners
event.Listener = Listener
function event.listen(name,callback,trace)
    return Listener:new(name,callback,trace)
end
-- listener methods
function Listener:remove()
    for i,listener in ipairs(event.__listeners[self.name]) do
        if listener == self then
            table.remove(event.__listeners[self.name],i)
            break
        end
    end
end
function Listener:setCallback(callback)
    self.callback = callback
end
return event