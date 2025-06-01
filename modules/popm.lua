-- ProjectOpen Package Manager why not
local fs = require("filesystem")
local http = require("internet")
local serialize = require("serialize")
local popm = {}
-- get active packages
popm.packages = fs.list("/packages/")
-- packages descriptor example
--[[
{
    name="myPackage"
    author="AuthorHere",
    description="DescriptionHere",
    version="v1.0",
    versionMajor = 1,
    versiomMinor = 0,
    dependencies = {
        someDependency = {
            url="UrlHere", -- URL points to one of these descriptors (per a version)
            expectedVersion="v1.0"
        }
    },
    files = {
        ["/bin/myCommand.lua"] = "URLOrCodeHere" -- when the PROGS var supports multiple targets all packages /bin/ will be targeted
    },
    -- main installer (runs on install if included)
    installer = "URLOrCodeHere"
}
--]]
local function codeOrUrl(unkown)
    if unkown:find("^http+s?%/") then
        -- load URL
        local handle = http.request(d.url)
        if not handle then
            return nil,"Invalid URL"
        end
        return handle:readAll()
    else
        return unkown
    end
end
-- add install command
function popm.install(descriptor)
    assert(descriptor.name and type(descriptor.name) == "string","Invalid package name")
    -- author is optinal
    -- if not it is Anonymous
    local name = descriptor.name
    local author = descriptor.author or "Anonymous"
    local description = descriptor.description or "No description"
    local version = descriptor.version or "Unkown"
    local dependencies = descriptor.dependencies or {}
    local files = descriptor.files or {}
    local installer = descriptor.installer
    -- you are expected to provide the correct rawgithubuser link if you use github
    -- check to see if we have that package
    local path = fs.combine("/packages/",name,version)
    fs.makeDirectory(fs.combine("/packages/",name,version))
    if not popm.packages[name] then
        -- create new package
        table.insert(popm.packages,name)
    end
    -- now that is set up
    -- let's get the dependencies
    for n,d in pairs(dependencies) do
        if not popm.packages[n] or not fs.exists(fs.combine("/packages/",n,d.version)) then
            -- if there is no valid URL it fails
            if not d.url then
                errorf("dependency %s doesn't have a valid install URL aborting install",n,2)
            end
            -- try to get package
            local handle = http.request(d.url)
            if not handle then
                errorf("dependency %s was doesn't have a valid install URL '%s' aborting install",n,d.url,2)
            end
            -- try to decode table
            local ok,depDescriptor = pcall(serialize.deserialize,handle:readAll())
            if not ok and depDescriptor then
                errorf("Failed to load dependency descriptor for %s reason:%s",n,depDescriptor,2)
            end
            -- check if version matches
            if not depDescriptor.version = d.expectedVersion then
                errorf("wrong version for dependency %s got version %s",n,depDescriptor.version,2)
            end
            -- check if name matches
            if not depDescriptor.name = n then
                errorf("name mismatch in dependency %s got %s",n,depDescriptor.name,2)
            end
            -- now attempt install
            local ok,package = pcall(popm.install(depDescriptor))
            if not ok and package then
                errorf("dependency %s failed to install by popm",n,2)
            end
        end
    end
    -- dependencies satisfied
    -- we can proceed
    -- first run installer script
    if installer then
        local code = codeOrUrl(installer)
        if not code then
        error("Invalid installer",2)
        end
        load(code)() -- sandbox in future
    end
    -- now download files
    for n,f in pairs(files) do
        -- attempt to get data
        local code = codeOrUrl(f)
        if not code then
            errorf("Failed to download file %s",n,2)
        end
        -- put in package
        local fileHandle = fs.open(fs.combine(path,n),"w")
        fileHandle:write(code)
        fileHandle:close()
    end
    -- save this descriptor in the package
    local fileHandle = fs.open(fs.combine(path,".descriptor"),"w")
    fileHandle:write(serialize.serialize(descriptor))
    fileHandle:close()
    return path
end
return popm
