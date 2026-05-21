local package = ...
local classes = require("classes")

---@class PkgInstance
---@field localpath string
---@field userpackages string
---@field globalpackages string
---@field loaded table<string, table>
local PkgInstance = classes.create("PkgInstance")

--- makes a localized instance
---@param from PkgInstance?
---@param descend string?
---@return PkgInstance
function PkgInstance:constructor(from, descend)
    local o = {}
    if from then
        o.localpath = from.localpath..(descend and ("/"..descend) or "")
        o.userpackages = from.userpackages
        o.globalpackages = from.globalpackages
    end
    o.loaded = {}
    return setmetatable(o, self)
end

PkgInstance.globalpackages = "users/kernel/packages"
PkgInstance.userpackages = ""
PkgInstance.localpath = "/"

package.globalinstance = PkgInstance:constructor()

-- methods
function PkgInstance:descend(path)
    return PkgInstance:constructor(self, path)
end

function PkgInstance:resolve(path)
    -- todo add resolver
end