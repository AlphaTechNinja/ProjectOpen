local access = _G.useraccess
_G.useraccess = nil
local filesystem = require("filesystem")
local serialize = require("serialize")
local users = {}
local USERSPATH = "/users/"

local function loadpermissions()
    local ok, permissions = pcall(dofile,USERSPATH.."permissions.slt")
    if not ok and permissions then
        permissions = {
            root = {
                privledge = math.huge
            }
        }
        filesystem.makeDirectory(USERSPATH.."root")
    end
    ---@cast permissions table<string, {privledge : number, metadata: table<string, any>?}>
    return permissions
end

local function savepermissions(new)
    local handle = filesystem.open(USERSPATH.."permissions.slt","w")
    handle:write(serialize.serialize(new))
    handle:close()
end

local commonPermNames = {
    [0] = "guest",
    [1] = "trusted guest",
    [2] = "user",
    [3] = "trusted user",
    [4] = "admin",
    [5] = "system admin",
    [math.huge] = "root",
}
local function clone(tab)
    local new = {}
    for n,v in pairs(tab) do
        if type(v) == "table" then
            new[n] = clone(v)
        else
            new[n] = v
        end
    end
    return new
end
local permissions = loadpermissions()
function  users.getUser()
    local user = access.getuser()
    return clone(user) -- no raw access for you!
end
function users.getLevel(username)
    local user = permissions[username]
    if not user then
        errorf("No such user %s", username, 2)
    end
    return user.privledge
end

function users.permissionName(level)
   return commonPermNames[level]
end

