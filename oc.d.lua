---@meta

---@class Component

---@class component
component = {}

---Returns the documentation string for the method with the specified name of the component with the specified address, if any. Note that you can also get this string by using tostring on a method in a proxy, for example `tostring(component.screen.isOn)`.
---@param address string
---@param method string
---@return string
function component.doc(address, method) end

---Calls the method with the specified name on the component with the specified address, passing the remaining arguments as arguments to that method. Returns the result of the method call, i.e. the values returned by the method. Depending on the called method's implementation this may throw.
---@param address string
---@param method string
---@param ... any
---@return any, ...
function component.invoke(address, method, ...) end

--- List components
---@param filter string?
---@param exact boolean?
---@return string[]
function component.list(filter, exact) end

--- Returns a list of the methods of the device at that address
---@param address string
---@return string[]
function component.methods(address) end

--- Create a proxy of a component
---@param address string
---@return Component
function component.proxy(address) end

--- Returns the type of component at that address
---@param address string
---@return string
function component.type(address) end

--- Fetches the slot of which the specified component is put in
---@param address string
---@return number
function component.slot(address) end

--- No documentation in the offical docs (for some reason)
---@param address string
---@return string
function component.fields(address) end

--- Accepts a abbreviated address and returns the full one
---@param address string
---@param type string?
---@return string?
---@return string?
function component.get(address, type) end

--- Checks to see if a component of the specified type is available
---@param type string
---@return boolean
function component.isAvailable(type) end

--- Gets a primary
---@param type string
---@return string?
function component.getPrimary(type) end

--- Sets the primary of that type
---@param type string
---@param address string
function component.setPrimary(type, address) end

--- Component definations

---@class Component3DPrinter : Component
---@class ComponentAbstractBus : Component
---@class ComponentAccessPoint : Component
---@class ComponentChunkLoader : Component
---@class ComponentComputer : Component
---@class ComponentCrafting : Component
---@class ComponentDataCard : Component
---@class ComponentDebug : Component
---@class ComponentDrone : Component
---@class ComponentDrive : Component
---@class ComponentEEPROM : Component
---@class ComponentExperience : Component
---@class ComponentFilesystem : Component
---@class ComponentGenerator : Component
---@class ComponentGeolyzer : Component
---@class ComponentGPU : Component
---@class ComponentHologram : Component
---@class ComponentInternet : Component
---@class ComponentInventoryController : Component
---@class ComponentLeash : Component
---@class ComponentMicroController : Component
---@class ComponentModem : Component
---@class ComponentMotionSensor : Component
---@class ComponentNavigation : Component
---@class ComponentNetSplitter : Component
---@class ComponentPiston : Component
---@class ComponentRedstone : Component
---@class ComponentRedstoneInMotion : Component
---@class ComponentRobot : Component
---@class ComponentScreen : Component
---@class ComponentSign : Component
---@class ComponentTankController : Component
---@class ComponentTractorBeam : Component
---@class ComponentTransposer : Component
---@class ComponentTunnel : Component
---@class ComponentWorldSensor : Component

--- Computer
---@class computer
computer = {}

--- Returns the address of this computer
---@return string
function computer.address() end

--- Returns the temporary boot address if it exists
---@return string?
function computer.tmpAddress() end

--- Returns the amount of memory left
---@return number
function computer.freeMemory() end

--- Returns the total amount of available memory
---@return number
function computer.totalMemory() end

--- Returns the amount of energy currently in the computer
---@return number
function computer.energy() end

--- Returns the amount of maximum energy the computer can store
---@return number
function computer.maxEnergy() end

--- Returns in seconds the amount of time the computer has been on
---@return number
function computer.uptime() end

--- Shuts off the computer
---@param reboot boolean?
function computer.shutdown(reboot) end

--- Gets the address of the filesystem this computer booted from
---@return string
function computer.getBootAddress() end

--- Set the boot address of this computer
---@param address string
function computer.setBootAddress(address) end

--- Returns the run level
---@return string|number
function computer.runLevel() end


--- Push signal
---@param name string
---@param ... string|number|boolean
function computer.pushSignal(name, ...) end

--- Pull signal
---@param timeout number
---@return string?
---@return ...<string|number|boolean>
function computer.pullSignal(timeout) end

--- Beep!
---@param frequency number
function computer.beep(frequency) end

--- globals

--- Compares the value type to the targets and if it doesnt match any, error
---@param index number
---@param value any
---@param targets string|table
function checkArg(index, value, targets) end