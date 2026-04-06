local access = _G.useraccess
_G.useraccess = nil
local sha256 = require("crypto.sha256")
local filesystem = require("filesystem")
local serialize = require("serialize")
local users = {}
local USERSPATH = "/users/"
-- current user takes the form of
--[[
    {
        name="<name>",
        level=<level>,
        metadata?=<metadata>
    }
]]
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
    ---@cast permissions table<string, {level : number,passwordsha : string?, metadata: table<string, any>?}>
    return permissions
end

local function savepermissions(new)
    local handle = filesystem.open(USERSPATH.."permissions.slt","w")
    handle:write("return "..serialize.serialize(new))
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

local function getuserraw(name)
    local user = permissions[name]
    assert(user, "No such user "..name)
    return user
end


function  users.getUser(name)
    if not name then
        local user = access.getuser()
        local o = clone(user) -- no raw access for you!
        return o
    end
    local o = clone(getuserraw(name))
    o.name = name
    o.passwordsha = nil
    return o
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

-- general

function users.isRoot(user)
    user = user or access.getuser()
    return user.level == math.huge
end

function users.level(user)
    user = user or access.getuser()
    return user.level
end

function users.minpriv(user, minlevel)
    local level = users.level(user)
    if level < minlevel then
        errorf("Below minimum privledge. Required %d got %d", minlevel, level, 2)
    end
end

function users.create(name, level, password)
    local cur = access.getuser()
    if level >= cur.level then
        error("Cannot create a user of greater or equal privledge than current", 2)
    end
    assert(name and type(name) == "string","Invalid username for new user")
    local newuser = {level=level}
    if password then
        assert(type(password) == "string","Password must be a string")
        newuser.passwordsha = sha256(password)
    end
    filesystem.makeDirectory(USERSPATH..name)
    permissions[name] = newuser
    savepermissions()
    return true
end

-- special
function users.login(name, password)
    local userobj = getuserraw(name)
    if userobj.passwordsha then
        assert(sha256(password) == userobj.passwordsha,"Wrong password")
    end
    access.setuser({
        level = userobj.level,
        metadata = clone(userobj.metadata)
    })
end

return users