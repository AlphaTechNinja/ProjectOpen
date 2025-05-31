local kernel = ...
local fs = kernel.filesystem
local event = kernel.event
local automounter = {}
kernel.automounter = automounter

automounter.mounterEvent = event.listen("component_added",function (addr,type)
    error(type)
    if type == "filesystem" then
        error("filesystem added")
        -- auto mount
        fs.mount("/mnt/"..addr:sub(1,3),addr)
    end
end)
automounter.unmounterEvent = event.listen("component_removed",function (addr,type)
    if type == "filesystem" then
        -- auto unmount
        fs.unmount(addr)
    end
end)