local access = _G.useraccess
_G.useraccess = nil
local sha256 = require("crypto.sha256")
local filesystem = require("filesystem")
local serialize = require("serialize")
local users = {}
local handles = {}
local USERSPATH = "/users/"

local function loginhandle(name,level)
    for i=#handles, 1, -1 do
        local ok, err = pcall(handles[i],{name=name,level=level})
        if not ok or not err then
            handles[i] = nil
        end
    end
end
-- current user takes the form of
--[[
    {
        name="<name>",
        level=<level>,
        metadata?=<metadata>
    }
]]

---@class User
---@field name string
---@field level integer
---@field metadata table<string, string|number>?

---@class RawUser : User
---@field passwordsha string

local function loadpermissions()
    local ok, permissions = pcall(dofile,USERSPATH.."permissions.slt")
    if not ok and permissions then
        permissions = {
            root = {
                level = math.huge
            }
        }
        filesystem.makeDirectory(USERSPATH.."root")
    end
    ---@cast permissions table<string, RawUser>
    return permissions
end

---@param new table<string, RawUser>
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

---@param name string
---@return RawUser
local function getuserraw(name)
    local user = permissions[name]
    assert(user, "No such user "..name)
    return user
end

---@param name string?
---@return User
function  users.getUser(name)
    if not name then
        local user = access.getuser()
        local o = clone(user) -- no raw access for you!
        o.__shellparse = function (self)
            return self.name
        end
        return o
    end
    local o = clone(getuserraw(name))
    o.name = name
    o.passwordsha = nil
    o.__shellparse = function (self)
        return self.name
    end
    return o
end

---@param username string
---@return integer
function users.getLevel(username)
    local user = permissions[username]
    if not user then
        errorf("No such user %s", username, 2)
    end
    return user.level
end

---@param level integer
---@return string
function users.permissionName(level)
   return commonPermNames[level]
end

-- general

---@param user string?
---@return boolean
function users.isRoot(user)
    ---@diagnostic disable-next-line
    user = user or access.getuser()
    return user.level == math.huge
end

---@param user string?
---@return integer
function users.level(user)
    ---@diagnostic disable-next-line
    user = user or access.getuser()
    return user.level
end

---@param user string
---@param minlevel integer
function users.minpriv(user, minlevel)
    local level = users.level(user)
    if level < minlevel then
        errorf("Below minimum privledge. Required %d got %d", minlevel, level, 2)
    end
end

---@param name string
---@param level integer
---@param password string?
---@return boolean
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
    savepermissions(permissions)
    return true
end

-- special
function users.login(name, password)
    local userobj = getuserraw(name)
    if userobj.passwordsha then
        assert(sha256(password) == userobj.passwordsha,"Wrong password")
    end
    local kernelrep = {
        name = name,
        level = userobj.level,
        metadata = clone(userobj.metadata)
    }
    access.setuser(kernelrep)
    loginhandle(name, userobj.level)
end

-- event
function users.onLogin(func)
    handles[#handles+1] = func
end

return users