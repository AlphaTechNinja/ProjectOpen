-- a debug stat
local stats = {}
stats.memory = tostring(computer.freeMemory()).."/"..tostring(computer.totalMemory())
local function percent(num)
    return string.format("%%%.2f", num * 100)
end

stats.memoryPercentageUsed = percent(1 - computer.freeMemory() / computer.totalMemory())
stats.memoryPercentageUnused = percent(computer.freeMemory() / computer.totalMemory())
stats.uptime = string.format("%.2fs", computer.uptime())
stats.pollerTasks = tostring(#kernel.poller.registered or 0)

local mounts = ""
for mount, addr in pairs(kernel.mounts) do
    mounts = mounts .. "mount["..mount.."] = " .. tostring(addr) .. "\n"
end

stats.mounts = mounts
-- concat and render
local result = ""
for n,v in pairs(stats) do
    result = result..n..": "..v.."\n"
end
return result.."\n"