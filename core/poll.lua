local poller = {}
local io = require("io")
-- this probaly doesn't need the classes to work
poller.registered = {}
function poller.register(poll, name)
    if poller.registered[name] then
        errorf("poller '%s' is already registered", name, 2)
    end

    local co = coroutine.create(function()
        while true do
            poll(coroutine.yield())
        end
    end)

    poller.registered[name] = co
end

function poller.unregister(poll)
    if type(poll) == "string" then
        local wasRegistered = not not poller.registered[poll]
        poller.registered[poll] = nil
        return wasRegistered
    else
        for n,p in pairs(poller.registered) do
            if p == poll then
                poller.registered[n] = nil
                return true
            end
        end
        return false
    end
end
function poller.poll(...)
    for name, co in pairs(poller.registered) do
        if coroutine.status(co) == "dead" then
            poller.registered[name] = nil
        else
            local ok, err = coroutine.resume(co, ...)
            if not ok and err then
                io.stderr:write(("poller '%s' crashed: %s\n"):format(name, err))
                poller.registered[name] = nil
            end
        end
    end
end

return poller