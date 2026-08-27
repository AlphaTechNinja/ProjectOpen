-- a better package manager (replaces resolving)
local classes = require("classes")
local fs = require("filesystem")
local sha256 = require("crypto.sha256")
local base64 = require("crypto.base64")
local http = require("internet")
local serialize = require("serialize")
local package = require("packageplus")

local lpm = {}

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

local function assurePackageFolders(user)
  local path = fs.combine("/users/", user)
  
  local Ppath = fs.combine(path,"packages")
  local Ppathe = fs.exists(Ppath)
  if not Ppathe then
    fs.makeDirectory(Ppath)
  end
  
  local Cpath = fs.combine(Ppath,".lpmconfig.slt")
  local conifg
  if not fs.exists(Cpath) then
    config = lpm.defaultConfig or {}
    local handle = fs.open(Cpath,"w")
    handle:write(serialize.serialize(config))
    handle:close()
  else
    config = serialize.deserializeFile(Cpath)
  end
  
  local Vpath = fs.combine(Ppath,".versions")
  if not fs.exists(Vpath) then
    fs.makeDirectory(Vpath)
    
    if not Ppathe then
      -- move existing packages into the correct version
      for _, package in ipairs(fs.list(Ppath)) do
        local packagepath = fs.combine(Ppath, package)
          local dest = fs.combine(Vpath, package, "local", "universal/")
          
          local manifestLua = fs.combine(packagepath, "manifest.lua")
          local manifestSlt = fs.combine(packagepath, "manifest.slt")
          if fs.exists(manifestLua) then
              local manifest = dofile(manifestLua)
              validateManifest(manifest, packagepath)
              if manifest.version or manifest.author then
                  dest = fs.combine(Vpath, package, manifest.author or "unknown", manifest.version or "universal")
              end
          end
          if fs.exists(manifestSlt) then
              local manifest = serialize.deserializeFile(manifestSlt, "lua")
              validateManifest(manifest, packagepath)
              if manifest.version or manifest.author then
                  dest = fs.combine(Vpath, package, manifest.author or "unknown", manifest.version or "universal")
              end
          end
          
        -- copy
        fs.copy(packagepath, dest)
      end
    end
  end
  
  return Ppath, Vpath, Cpath, config
end

-- some actual things
local PkgUser = classes.create("PkgUser")
lpm.PkgUser = PkgUser
function PkgUser:constructor(user)
    assert(fs.exists(fs.combine("users", user)), "User does not exists")
    local Ppath, Vpath, Cpath, config = assurePackageFolders(user)
    return setmetatable({user=user,Upath=fs.combine("users",user),Ppath=Ppath,Vpath=Vpath,Cpath=Cpath,config=config},self)
end

function PkgUser:listPackages()
    return lpm.list(self.user)
end

-- config contains things like what to default to when there are multiple packages of the same name 
function PkgUser:getPackages(name, author, version)
    return lpm.filterPackages(self.user, self.config, name, author, version)
end

-- methods
function lpm.list(user)
    -- return in structure of author -> package -> version
    local Upath = fs.combine("users", user)
    local Ppath = fs.combine(Upath, "packages")
    local Vpath = fs.combine(Ppath, ".versions")
    
    local authors = fs.list(Vpath)
    local authorsStructured = {}
    
    for i=1, #authors do
        local author = authors[i]
        local packages = fs.list(fs.combine(Vpath, author))
        local packagesStructured = {}
        for j=1, #packages do
            local package = packages[j]
            local versions = fs.list(fs.combine(Vpath, author, package))
            packagesStructured[package] = versions
        end
        authorsStructured[author] = packagesStructured
    end
    
    return authorsStructured
end

return lpm