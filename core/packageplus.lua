local package = ...
local users = require("user")
local fs = require("filesystem")
local classes = require("classes")
local serialize = require("serialize")

---@class PkgInstance
---@field localpath string
---@field userpackages string
---@field globalpackages string
---@field loaded table<string, table>
local PkgInstance = classes.create("PkgInstance")

local function ensureLuaPath(path)
    local _, ext = fs.splitFilename(path)
    if ext and ext ~= "" then
        return path
    end
    return path .. ".lua"
end

local function validateManifest(manifest, packagepath)
    if type(manifest) ~= "table" then
        errorf("invalid manifest at '%s' (table expected)", packagepath, 2)
    end
    if manifest.entry ~= nil and type(manifest.entry) ~= "string" and type(manifest.entry) ~= "function" then
        errorf("invalid manifest.entry at '%s' (string/function expected)", packagepath, 2)
    end
    if manifest.exports ~= nil and type(manifest.exports) ~= "table" then
        errorf("invalid manifest.exports at '%s' (table expected)", packagepath, 2)
    end
end

local function compileManifestEntry(manifest, packagepath)
    if type(manifest.entry) == "function" then
        return manifest.entry
    end

    if type(manifest.entry) == "string" then
        local entry = fs.combine(packagepath, ensureLuaPath(manifest.entry))
        if not fs.exists(entry) then
            errorf("manifest entry not found '%s'", entry, 2)
        end
        return entry
    end

    if type(manifest.exports) == "table" then
        local exports = manifest.exports
        return function()
            local out = {}
            for exportName, exportPath in pairs(exports) do
                if type(exportName) ~= "string" or type(exportPath) ~= "string" then
                    errorf("invalid export mapping in package '%s'", packagepath, 2)
                end
                local filepath = fs.combine(packagepath, ensureLuaPath(exportPath))
                if not fs.exists(filepath) then
                    errorf("missing exported file '%s' in package '%s'", exportPath, packagepath, 2)
                end
                local loaded = dofile(filepath)
                out[exportName] = loaded == nil and true or loaded
            end
            return out
        end
    end

    local defaultEntry = fs.combine(packagepath, "init.lua")
    if fs.exists(defaultEntry) then
        return defaultEntry
    end
    return nil, "manifest has no entry/exports and package has no init.lua"
end

--- makes a localized instance
---@param from PkgInstance?
---@param descend string?
---@return PkgInstance
function PkgInstance:constructor(from, descend)
    local o = {}
    if from then
        o.localpath = from.localpath .. (descend and ("/" .. descend) or "")
        o.userpackages = from.userpackages
        o.globalpackages = from.globalpackages
    end
    o.loaded = {}
    return setmetatable(o, self)
end

PkgInstance.globalpackages = "/users/kernel/packages"
PkgInstance.userpackages = ""
PkgInstance.localpath = "/"

package.globalinstance = PkgInstance:constructor()

function PkgInstance:descend(path)
    return PkgInstance:constructor(self, path)
end

function PkgInstance:resolveLocal(path, options)
    assert(path:sub(1, 1) == "/" or path:sub(1, 2) == "./", "Not a local path!")
    path = path:sub(1, 2) ~= "./" and path or path:sub(3)
    path = path:sub(1, 1) ~= "/" and path or path:sub(2)
    local basepath = fs.combine(self.localpath, path)
    local _, ext = fs.splitFilename(path)

    if fs.exists(basepath) then
        if fs.isDirectory(basepath) then
            local resolved, err = self:resolveLocal(fs.combine(basepath, "init.lua"), options)
            if not resolved then
                return nil, err
            end
            return resolved, fs.stepback(resolved)
        end
        return basepath, fs.stepback(basepath)
    end

    if not ext or ext == "" then
        local withExt = basepath .. ".lua"
        if fs.exists(withExt) then
            return withExt, fs.stepback(withExt)
        end
    end

    return nil, "local path doesnt exists"
end

function PkgInstance:resolveUser(path, options)
    options = options or {}
    local user = options.user or users.getUser().name
    local packagespath = options.packagespath or fs.combine("/users/", user, "/packages/")
    if not fs.exists(packagespath) then
        return nil, "no packages", ""
    end

    local packagepath = fs.combine(packagespath, path)
    if not fs.exists(packagepath) or not fs.isDirectory(packagepath) then
        return nil, "package not found", ""
    end

    local manifestLua = fs.combine(packagepath, "manifest.lua")
    local manifestSlt = fs.combine(packagepath, "manifest.slt")
    if fs.exists(manifestLua) then
        local manifest = dofile(manifestLua)
        validateManifest(manifest, packagepath)
        local entry, err = compileManifestEntry(manifest, packagepath)
        if not entry then
            return nil, err, ""
        end
        return packagepath, packagepath, entry
    end
    if fs.exists(manifestSlt) then
        local manifest = serialize.deserializeFile(manifestSlt, "lua")
        validateManifest(manifest, packagepath)
        local entry, err = compileManifestEntry(manifest, packagepath)
        if not entry then
            return nil, err, ""
        end
        return packagepath, packagepath, entry
    end

    local entry = fs.combine(packagepath, "init.lua")
    if fs.exists(entry) then
        return packagepath, packagepath, entry
    end
    return nil, "malformed package", ""
end

--- resolves a path for this package instance
---@param path string
---@param options table?
---@return string?
---@return string?
---@return boolean?
function PkgInstance:resolve(path, options)
    options = options or {}
    local start = path:sub(1, 1)
    local isExplicitLocal = (start == "/") or (path:sub(1, 2) == "./")

    if isExplicitLocal then
        local resolved, basepath = self:resolveLocal(path, options)
        if resolved then
            return resolved, basepath, false
        end
        return nil, "Unable to resolve local path"
    end

    local packagepath, basepath, entry = self:resolveUser(path, options)
    if packagepath then
        return entry, basepath, true
    end

    local gPath = self.globalpackages or "/users/kernel/packages"
    local gPackagepath, gBasepath, gEntry = self:resolveUser(path, {
        user = options.globalUser or "kernel",
        packagespath = gPath
    })
    if gPackagepath then
        return gEntry, gBasepath, true
    end

    return nil, "Unable to resolve path"
end

package.PkgInstance = PkgInstance
function package.instance(path)
    return PkgInstance:constructor(package.globalinstance, path)
end

local function createChildInstance(parent, basepath)
    local child = PkgInstance:constructor(parent)
    child.localpath = basepath or parent.localpath
    return child
end

local function makePackageWrapper(instance)
    local wrapper = {}
    setmetatable(wrapper, { __index = package })

    wrapper.globalinstance = instance
    wrapper.instance = function(path)
        return PkgInstance:constructor(instance, path)
    end
    wrapper.import = function(path, options)
        return instance:import(path, options)
    end
    return wrapper
end

--- imports a module/package entry with instance-scoped resolution and caching
---@param path string
---@param options table?
---@return any
function PkgInstance:import(path, options)
    options = options or {}
    local resolved, basepath, isPackage = self:resolve(path, options)
    if not resolved then
        errorf("unable to import '%s' (%s)", tostring(path), tostring(basepath or "unknown"), 2)
    end

    local cacheKey = type(resolved) == "string" and resolved or (tostring(path) .. "::function")
    if self.loaded[cacheKey] ~= nil then
        return self.loaded[cacheKey]
    end

    local active = createChildInstance(self, basepath)
    local wrappedPackage = makePackageWrapper(active)
    local result

    if type(resolved) == "function" then
        result = resolved({
            package = wrappedPackage,
            instance = active,
            basepath = basepath,
            isPackage = isPackage == true
        })
    else
        local env = setmetatable({
            package = wrappedPackage
        }, { __index = _G })
        local chunk, err = loadfile(resolved, "t", env)
        if not chunk and err then
            error(err, 2)
        end
        result = chunk()
    end

    if result == nil then
        result = true
    end
    self.loaded[cacheKey] = result
    return result
end

package.import = function(path, options)
    return package.globalinstance:import(path, options)
end

return package
