local completion = {}
local fs = require("filesystem")

local function completeFiltered(cwd, path, filterFunc)
    local full = fs.combine(cwd, path)
    local target

    if path:sub(-1) == "/" then
        if fs.exists(full) and fs.isDirectory(full) then
            target = full
        else
            return {}
        end
    else
        target = fs.combine(full, "/..")
        if not (fs.exists(target) and fs.isDirectory(target)) then
            return {}
        end
    end

    local basename = path:match("([^/]+)$") or ""
    local possibleTargets = fs.list(target)
    local filtered = {}

    for i = 1, #possibleTargets do
        local name = possibleTargets[i]
        local fullPath = fs.combine(target, name)
        if name:find("^" .. basename) and (not filterFunc or filterFunc(fullPath)) then
            local relative = path:sub(-1) == "/" and path .. name or path:gsub("[^/]+$", "") .. name
            table.insert(filtered, relative)
        end
    end

    table.sort(filtered, function(a, b)
        return #a == #b and a < b or #a < #b
    end)

    return filtered
end

function completion.completePath(cwd, path)
    return completeFiltered(cwd, path, nil)
end

function completion.completeFile(cwd, path)
    return completeFiltered(cwd, path, function(fullPath)
        return not fs.isDirectory(fullPath)
    end)
end

function completion.completeDirectory(cwd, path)
    return completeFiltered(cwd, path, function(fullPath)
        return fs.isDirectory(fullPath)
    end)
end
local function alphabetical(a, b)
    return a < b
end
local function lengthwise(a, b)
    return #a < #b
end
function completion.options(selectable, input, options)
    -- just filter selectable items if they contain the input
    local filtered = {}
    for i=1,#selectable do
        local item = selectable[i]
        if item:find("^" .. input) then
            table.insert(filtered,item)
        end
    end
    -- filter by standard function or option selected sorter
    local sorter
    if options.mode == "custom" then
        sorter = options.sorter
    elseif options.mode == "alphabetical" then
        sorter = alphabetical
    elseif options.mode == "lengthwise" then
        sorter = lengthwise
    else
        sorter = alphabetical
    end
    -- and sort
    table.sort(filtered,sorter)
    return filtered
end
function completion.completeShellVar(input,shellVars,options)
    -- just an options completion
    local items = {}
    for n,_ in pairs(shellVars) do
        table.insert(items,"$"..n)
    end
    return completion.options(items,input,options)
end
function completion.decodeCompletion(input,completionOptions,shell)
    if completionOptions.variableArgs then
        -- undetermined amount of variables
        local varMatch = completionOptions.arg[#completionOptions.arg] -- grab last type
        if not varMatch then
            return {} -- no completeions
        end
        
    end
end