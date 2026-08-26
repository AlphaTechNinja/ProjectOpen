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
  
  local Vpath = fs.combine(Ppath,".versions")
  if not fs.exists(Vpath) then
    fs.makeDirectory(Vpath)
    
    if not Ppathe then
      -- move existing packages into the correct version
      for _, package in ipairs(fs.list(Ppath)) do
        local packagepath = fs.combine(Ppath, package)
          local dest = fs.combine(Vpath, package, "universal/")
          
          local manifestLua = fs.combine(packagepath, "manifest.lua")
          local manifestSlt = fs.combine(packagepath, "manifest.slt")
          if fs.exists(manifestLua) then
              local manifest = dofile(manifestLua)
              validateManifest(manifest, packagepath)
              if manifest.version then
                  dest = fs.combine(Vpath, package, manifest.version)
              end
          end
          if fs.exists(manifestSlt) then
              local manifest = serialize.deserializeFile(manifestSlt, "lua")
              validateManifest(manifest, packagepath)
              if manifest.version then
                  dest = fs.combine(Vpath, package, manifest.version)
              end
          end
          
        -- copy
        fs.copy(packagepath, dest)
      end
    end
  end
  
  return Ppath, Vpath
end

-- some actual things
local PkgUser = classes.create("PkgUser")
lpm.PkgUser = PkgUser
function PkgUser:constructor(user)
    assert(fs.exists(fs.combine("users", user)), "User does not exists")
    return setmetatable({user=user,path=fs.combine("users",user)},self)
end

--function PkgUser:listPackages()
    