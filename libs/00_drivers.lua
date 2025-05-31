-- modifies components for virtual components
local orginalcomponent = component
local drivers = {}
local registered = {}
local proxies = setmetatable({},{
    __mode = "v"
})
function generateUUID()
    local template = "xxxxxxxx-xxxx-4xxx-yxxx-xxxxxxxxxxxx"
    return template:gsub("[xy]", function (c)
        local v = (c == "x") and math.random(0, 15) or math.random(8, 11)
        return string.format("%x", v)
    end)
end

function drivers.registerdriver(driver)
    local fakeUUID = generateUUID()
    registered[fakeUUID] = driver
    computer.pushSignal("component_added",fakeUUID,driver.type) -- add support for component_added
end
-- new list
function drivers.list(type, exact)
    local results = {}
    for address, driver in pairs(registered) do
        if not type or (exact and driver.type == type) or (not exact and driver.type:find(type)) then
            results[address] = driver.type
        end
    end
    for address, dtype in orginalcomponent.list(type, exact) do
        results[address] = dtype
    end
    return function()
        local k, v = next(results)
        if k then
            results[k] = nil -- remove to avoid repeat
            return k, v
        end
    end
end
function drivers.invoke(address,method,...)
    if registered[address] then
        local driver = registered[address]
        if driver[method] then
            return driver[method](...)
        end
    else
        return orginalcomponent.invoke(address,method,...)
    end
end
function drivers.proxy(address)
    if proxies[address] then
        return proxies[address]
    end
    if registered[address] then
        -- wrap
        local wrapper = setmetatable({},{__index=registered[address]})
        proxies[address] = wrapper
        return wrapper
    else
        return orginalcomponent.proxy(address)
    end
end
function drivers.isAvailable(type)
    return drivers.list(type)() ~= nil
end
component = setmetatable(drivers,{
    __index = orginalcomponent
})