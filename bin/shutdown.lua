local args = {...}
local shell = table.remove(args, 1)
-- shutsdown the computer (optinally reboot like normal)
local validReboot = {
    "True","true","-T","-t","1","Y"
}
local reboot = false
if args[1] then
    for _,v in ipairs(validReboot) do
        if args[1] == v then
            reboot = true
        end
    end
end
computer.shutdown(reboot)