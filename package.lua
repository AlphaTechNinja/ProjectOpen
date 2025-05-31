local kernal = ...
local package = {}

package.loaded = {
    filesystem = kernal.filesystem,
    classes = kernal.classes,
    os = os,
    component = component,
    computer = computer
}

package.loaded.package = package
package.path = "/core/?.lua;/modules/?.lua;/?.lua;/objects/?.lua;/modules/?.lua"

function package.require(name)
    checkArg(1, name, "string")
    
    if package.loaded[name] then
        return package.loaded[name]
    end

    local tried = {}
    local formattedName = name:gsub("%.", "/")
    local fs = kernal.filesystem

    for path in package.path:gmatch("[^;]+") do
        local filepath = path:gsub("%?", formattedName)
        if fs.exists(filepath) then
            local chunk, err = loadfile(filepath)
            if not chunk then
                error(err, 2)
            end
            local result = chunk()
            package.loaded[name] = result or true
            return package.loaded[name]
        else
            table.insert(tried, filepath)
        end
    end

    error("module '" .. name .. "' not found:\n  tried:\n  " .. table.concat(tried, "\n  "), 2)
end
function package.delay(lib,full) -- like openos to minimize use of full loading
    return setmetatable(lib,{
        __index = function (t, k)
            dofile(full,t)
            setmetatable(t,nil)
            return t[k]
        end
    })
end
require = package.require
return package