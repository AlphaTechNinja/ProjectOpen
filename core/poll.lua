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
            local ok, err = poller.resumeLocked(co, function ()
                -- logging may go here in debug
            end, nil, ...)
            if not ok and err then
                io.stderr:write(("poller '%s' crashed: %s\n"):format(name, err))
                poller.registered[name] = nil
            end
        end
    end
end
-- thread locking
local locks = {}

--- Yield and pass a key to the callback to unlock
---@param callback fun(key : table) : nil
---@param ... any
---@return ...
function poller.yieldLocked(callback, ...)
    local thread = coroutine.running()
    if locks[thread] then
        error("Coroutine is already locked", 2)
    end
    local key = {} -- any unique object works
    locks[thread] = key
    
    callback(key)
    return coroutine.yield(...)
end

--- Resume a locked thread
---@param thread thread
---@param mode function | "default" | "silent" | nil
---@param key table?
---@param ... any
---@return boolean?
function poller.resumeLocked(thread, mode, key, ...)
    mode = mode or "default"
    if not locks[thread] then
        return coroutine.resume(thread, ...)
    end
    
    if locks[thread] == key then
        locks[thread] = nil -- unlock
        return coroutine.resume(thread, ...)
    else
        -- check mode
        if type(mode) == "function" then
            -- fail callback
            return mode()
        end
        if mode == "default" then
            error("can not unlock coroutine "..thread.." as the provided key is invalid", 2)
        elseif mode == "silent" then
            return
        end
    end
end

return poller