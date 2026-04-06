-- promise system
local classes = require("classes")
local Promise = classes.create("Promise")
local polling = {}
function Promise:constructor(handler)
    -- if handler add it to the queue
    local prom = {}
    prom.status = "pending"
    prom.val = nil
    if handler then
        local co = coroutine.create(function ()
            repeat
                handler(prom.resolve,prom.reject)
                coroutine.yield(false)
            until prom.status ~= "pending"
            coroutine.yield(true)
        end)
        prom.__handler = co
        table.insert(polling,prom)
    end
    function prom.resolve(val)
        if prom.status ~= "pending" then return end
        prom.status = "resolved"
        prom.val = val
        -- handle all resolvers
        for i=1,#prom.__onResolve do
            pcall(prom.__onResolve[i],val)
        end
    end
    function prom.reject(err)
        if prom.status ~= "pending" then return end
        prom.status = "rejected"
        prom.val = err
        for i=1,#prom.__onReject do
            pcall(prom.__onReject[i],err)
        end
    end
    function prom.onResolve(func)
        prom.__onResolve[#prom.__onResolve+1] = func
    end
    function prom.onReject(func)
        prom.__onReject[#prom.__onReject+1] = func
    end
    -- helper for dependant promises
    prom.__onResolve = {}
    prom.__onReject = {}
    return prom
end
function Promise.poller()
    local i = 1
    while i <= #polling do
        local status,exit = coroutine.resume(polling[i].__handler)
        if not status then
            polling[i].reject(exit)
            table.remove(polling,i)
        end
        if exit == true then
            table.remove(polling,i)
            i = i - 1
        end
        i = i + 1
    end
end
-- helpers
function Promise.Await(prom)
    if type(prom) == "table" and getmetatable(prom) and prom.isOf and prom:isOf(Promise) then
        -- we can wait for it
        while prom.status == "pending" do
            coroutine.yield()
        end
        if prom.status == "rejected" and #prom.__onReject < 1 then
            error(prom.val)
        elseif prom.status == "rejected" then
            return nil,prom.val
        end
        return prom.val
    end
end
function Promise:Then(func)
    -- make a new promise waiting for the orginal one to resolve
    local waiter = Promise:new()
    self.onResolve(function (val)
        waiter.resolve(func(val))
    end)
    self.onReject(function ()
        waiter.reject()
    end)
    return waiter
end
function Promise:Catch(func)
    local waiter = Promise:new()
    self.onReject(function (val)
        waiter.resolve(func(val))
    end)
    self.onResolve(function ()
        waiter.reject()
    end)
    return waiter
end
function Promise:Race(...)
    -- first one to complete is used as the return value all others are ignored
    local proms = {...}
    return Promise:new(function (resolve,reject)
        for i=1,#proms do
            if proms[i].status == "resolved" then
                resolve(proms[i].val)
            end
        end
    end)
end
function Promise:All(...)
    -- waits for all to resolve or reject
    local proms = {...}
    return Promise:new(function (resolve,reject)
        local done = true
        for i=1,#proms do
            if proms[i].status == "pending" then
                done = false
            end
        end
        if done then
            resolve()
        end
    end)
end
return Promise
