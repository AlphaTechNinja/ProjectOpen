-- basic fs
-- doesnt require any readfile, loadfile, or dofile
-- as this overrides it
checkArg = checkArg
local kernal = ...
local classes = kernal.classes
---@class fs
local fs = {}
local mounts = {
    ["/"] = computer.getBootAddress()
} -- protect mounts
kernal.mounts = mounts
-- tools
local function toProxy(unkown)
    if type(unkown) == "table" then
        return unkown
    else
        return component.proxy(unkown)
    end
end

---@param path string
---@return string[]
function fs.splitPath(path)
    -- simply splits by /
    local tokens = {}
    for token in path:gmatch("[^/]+") do
        table.insert(tokens,token)
    end
    return tokens
end

---@param path string
---@return string
---@return string
function fs.splitFilename(path)
    local name, ext = string.match(path, "(.+)%.(.+)")
    return name, ext
end

---@param path string
---@return string
function fs.simplify(path)
    local basepath = fs.splitPath(path)
    local simplified = {}
    for _,step in ipairs(basepath) do
        if step == ".." then
            table.remove(simplified)
        else
            table.insert(simplified,step)
        end
    end
    return "/"..table.concat(simplified,"/")
end

---@param ... string
---@return string
function fs.combine(...)
    return fs.simplify(table.concat(({...}),"/"))
end
-- main logic

---@param path string
---@return string
---@return table|unknown
function fs.resolve(path)
    path = fs.simplify(path)
    local fullpath = "/"
    local localpath = "/"
    local filesystem = mounts["/"]

    for _, segment in ipairs(fs.splitPath(path)) do
        local tryPath = fs.simplify(fullpath .. "/" .. segment)
        if mounts[tryPath] then
            filesystem = mounts[tryPath]
            localpath = "/"
        else
            localpath = fs.simplify(localpath .. "/" .. segment)
        end
        fullpath = tryPath
    end

    return localpath, toProxy(filesystem)
end
-- global functions

---@param path string
---@return boolean
function fs.exists(path)
    local localpath, filesystem = fs.resolve(path)
    return filesystem.exists(localpath)
end

---@param path string
---@return boolean
function fs.isReadOnly(path)
    local localpath, filesystem = fs.resolve(path)
    return filesystem.isReadOnly()
end

---@param path string
---@return unknown
function fs.makeDirectory(path)
    local localpath, filesystem = fs.resolve(path)
    return filesystem.makeDirectory(localpath)
end

---@param path string
---@return boolean
function fs.isDirectory(path)
    local localpath, filesystem = fs.resolve(path)
    return filesystem.isDirectory(localpath)
end

---@param path string
---@return string[]
function fs.list(path)
    local localpath, filesystem = fs.resolve(path)
    return filesystem.list(localpath)
end

---@param source string
---@param dest string
---@return boolean
function fs.rename(source,dest)
    local slocalpath, sfilesystem = fs.resolve(source)
    local dlocalpath, dfilesystem = fs.resolve(dest)
    -- first check if same path
    if sfilesystem == dfilesystem then
        return sfilesystem.rename(slocalpath,dlocalpath)
    end
    -- else open a handle then move data
    local readhandle = fs.open(source,"r")
    local writehandle = fs.open(dest,"w")
    writehandle:write(readhandle:readAll())
    writehandle:close()
    return true
end

---@param path string
---@param filesystem any
function fs.mount(path,filesystem)
    checkArg(2,filesystem,{"table","string"})
    if mounts[path] then
        errorf("A mount already exists at '%s'",path,2)
    end
    mounts[path] = filesystem
end

---@param path string
function fs.unmount(path)
    checkArg(1,path,"string")
    -- first check if it is an path
    if mounts[path] then
        mounts[path] = nil
        return 1 -- number of unmounts
    end
    -- else search for it (all occurences)
    local unmounted = 0
    local i = 1
    while i <= #mounts do
        local mnt = mounts[i]
        if mnt == path then
            i = i - 1
            unmounted = unmounted + 1
            mounts[i] = nil
        end
        i = i + 1
    end
    return unmounted
end
-- files
---@class file
---@field new fun(self : self, path : string, mode : "r"|"w") : file
---@field __fs any
---@field __handle integer
local file = classes.create("FileHandle")
fs.file = file

---@param path string
---@param mode "r"|"w"
---@return table?
function file:constructor(path,mode)
    mode = mode or "r"
    if mode == "r" then
        -- construct in read mode
        local localpath, filesystem = fs.resolve(path)
        -- invoke open
        local handle,err = filesystem.open(localpath,"r")
        if not handle and err then
            errorf("Unable to open '%s' (maybe it doesn't exists?)",path,2)
        end
        return setmetatable({__handle = handle,__fs = filesystem,__mode="r",__close = false},self)
    elseif mode == "w" then
        -- construct in write mode
        local localpath, filesystem = fs.resolve(path)
        -- invoke write
        local handle,err = filesystem.open(localpath,"w")
        if not handle and err then
            errorf("Unable to write to '%s' (maybe read only?)",path,2)
        end
        return setmetatable({__handle = handle,__fs = filesystem,__mode="w",__close = false},self)
    else
        errorf("Invalid file handle mode '%s'",mode,2)
    end
end
-- methods
function file:close()
    if self.__close then return end
    self.__fs.close(self.__handle)
    self.__close = true
end

---@param len integer
---@return string
function file:read(len)
    len = len or 1
    if self.__close then error("Attempted to read a closed handle",2) end
    return self.__fs.read(self.__handle,len)
end

---@param data string
---@return unknown
function file:write(data)
    checkArg(1,data,"string")
    if self.__close then error("Attempted to read a closed handle",2) end
    return self.__fs.write(self.__handle,data)
end

---@param whence "start"|"relative"|"end"
---@param offset integer
---@return integer
function file:seek(whence,offset)
    if self.__close then error("Attempted to seek a closed handle",2) end
    return self.__fs.seek(whence,offset)
end

---@return boolean
function file:isClosed()
    return self.__close
end

---@param noclose boolean?
---@return string
function file:readAll(noclose)
    local buffer = {}
    while true do
        local data = self:read(math.huge)
        if not data then break end
        table.insert(buffer, data)
    end    
    if not noclose then
        self:close()
    end
    return table.concat(buffer,"")
end
-- add here
---@param path string
---@param mode "r"|"w"
---@return file
function fs.open(path,mode)
    return file:new(path,mode)
end
-- overrides
function readfile(path)
    local handle = fs.open(path,"r")
    return handle:readAll()
end
return fs