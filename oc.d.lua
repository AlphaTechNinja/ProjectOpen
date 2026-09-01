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
local Component3DPrinter = {}
---@class ComponentAbstractBus : Component
local ComponentAbstractBus = {}
---@class ComponentAccessPoint : Component
local ComponentAccessPoint = {}
---@class ComponentChunkLoader : Component
local ComponentChunkLoader = {}
---@class ComponentComputer : Component
local ComponentComputer = {}
---@class ComponentCrafting : Component
local ComponentCrafting = {}
---@class ComponentDataCard : Component
local ComponentDataCard = {}
---@class ComponentDebug : Component
local ComponentDebug = {}
---@class ComponentDrone : Component
local ComponentDrone = {}
---@class ComponentDrive : Component
local ComponentDrive = {}
---@class ComponentEEPROM : Component
local ComponentEEPROM = {}
---@class ComponentExperience : Component
local ComponentExperience = {}
---@class ComponentFilesystem : Component
local ComponentFilesystem = {}
---@class ComponentGenerator : Component
local ComponentGenerator = {}
---@class ComponentGeolyzer : Component
local ComponentGeolyzer = {}
---@class ComponentGPU : Component
local ComponentGPU = {}
---@class ComponentHologram : Component
local ComponentHologram = {}
---@class ComponentInternet : Component
local ComponentInternet = {}
---@class ComponentInventoryController : Component
local ComputerInventoryController = {}
---@class ComponentLeash : Component
local ComponentLeash = {}
---@class ComponentMicroController : Component
local ComponentMicroController = {}
---@class ComponentModem : Component
local ComponentModem = {}
---@class ComponentMotionSensor : Component
local ComponentMotionSensor = {}
---@class ComponentNavigation : Component
local ComponentNavigation = {}
---@class ComponentNetSplitter : Component
local ComponentNetSplitter = {}
---@class ComponentPiston : Component
local ComponentPiston = {}
---@class ComponentRedstone : Component
local ComponentRedstone = {}
---@class ComponentRedstoneInMotion : Component
local ComponentRedstoneInMotion = {}
---@class ComponentRobot : Component
local ComponentRobot = {}
---@class ComponentScreen : Component
local ComponentScreen = {}
---@class ComponentSign : Component
local ComponentSign = {}
---@class ComponentTankController : Component
local ComponentTankController = {}
---@class ComponentTractorBeam : Component
local ComponentTractorBeam = {}
---@class ComponentTransposer : Component
local ComponentTransposer = {}
---@class ComponentTunnel : Component
local ComponentTunnel = {}
---@class ComponentWorldSensor : Component
local ComponentWorldSensor = {}

--- 3DPrinter

--- Begins printing
---@param count integer
---@return boolean
function Component3DPrinter.commit(count) end

--- Sets the resulting objects name
---@param label string
function Component3DPrinter.setLabel(label) end

--- Returns object label
---@return string
function Component3DPrinter.getLabel() end

--- Sets the object's tooltip
---@param tooltip string
function Component3DPrinter.setTooltip(tooltip) end

--- Gets the object's tooltip
---@return string
function Component3DPrinter.getTooltip() end

--- Controls wether the resulting object will behave like a button or not
---@param mode boolean
function Component3DPrinter.setButtonMode(mode) end

--- Returns if it is in button mode or not
---@return boolean
function Component3DPrinter.isButtonMode() end

--- Controls wether the object emits redstone or not
---@param mode boolean
function Component3DPrinter.setRedstoneEmitter(mode) end

--- Returns if it emits redstone or not
---@return boolean
function Component3DPrinter.isRedstoneEmitter() end

--- Adds a new shape to the current Object
---@param mixX integer
---@param minY integer
---@param minZ integer
---@param maxX integer
---@param maxY integer
---@param maxZ integer
---@param texture string
---@param state boolean?
---@param tint integer?
---@return boolean
function Component3DPrinter.addShape(mixX, minY, minZ, maxX, maxY, maxZ, texture, state, tint) end

--- Returns the number of shapes in the object
---@return integer
function Component3DPrinter.getShapeCount() end

--- Returns the maximum number of shapes the machine allows
---@return integer
function Component3DPrinter.maxShapeCount() end

--- Get print job status
---@return "idle" | "busy"
---@return integer | boolean
function Component3DPrinter.status() end

--- Clears job
function Component3DPrinter.reset() end

--- Abstract bus

--- Gets the enabled status of the bus
---@return boolean
function ComponentAbstractBus.getEnabled() end

--- Turns on and off the bus
---@param enabled boolean
function ComponentAbstractBus.setEnabled(enabled) end

--- Returns local address on bus
---@return integer
function ComponentAbstractBus.getAddress() end

--- Set local address
---@param address integer
function ComponentAbstractBus.setAddress(address) end

--- Scans for devices on the bus
---@param mask integer
---@return [unknown]
function ComponentAbstractBus.scan(mask) end

--- Set data over bus
---@param address integer
---@param data table<string, string>
function ComponentAbstractBus.send(address, data) end

--- Max packet size
---@return integer
function ComponentAbstractBus.maxPacketSize() end

--- Access point

--- Return configured signal strength
---@return integer
function ComponentAccessPoint.getStrength() end

--- Set access point strength
---@param strength integer
function ComponentAccessPoint.setStrength(strength) end

--- Get repeater configuration
---@return boolean
function ComponentAccessPoint.isRepeater() end

--- Set repeater configuration
---@param repeater boolean
---@return boolean
function ComponentAccessPoint.setRepeater(repeater) end

--- Chunkloader

--- Self explanitory
---@return boolean
function ComponentChunkLoader.isActive() end

--- Self explanitory
---@param mode boolean
---@return boolean
function ComponentChunkLoader.setActive(mode) end

--- Computer

--- Start a computer
---@return boolean
function ComponentComputer.start() end

--- Shutdown a computer
---@return boolean
function ComponentComputer.stop() end

--- Gets running status
---@return boolean
function ComponentComputer.isRunning() end

--- Plays a beep
---@param frequency number
---@param duration number
function ComponentComputer.beep(frequency, duration) end

--- Fetches information about a computer
---@return table
function ComponentComputer.getDeviceInfo() end

--- Attempts to crash a computer for a specific reason
---@param reason string
function ComponentComputer.crash(reason) end

--- Returns the computer's architecture
---@return string
function ComponentComputer.getArchitecture() end

--- Checks if the computer is a robot
---@return boolean
function ComponentComputer.isRobot() end

--- Crafting

--- Attempts to craft the specified amount of items
---@param count integer
function ComponentCrafting.craft(count) end

--- Data card



--- Filesystem

--- Return space used
---@return integer
function ComponentFilesystem.spaceUsed() end

--- Opens a file handle
---@param path string
---@param mode "r" | "w"
---@return integer handle
function ComponentFilesystem.open(path, mode) end

--- Seeks a file handle
---@param handle integer
---@param whence "end" | "relative" | "start"
---@param offset integer
---@return integer position
function ComponentFilesystem.seek(handle, whence, offset) end

--- Creates a directory at the specified path
---@param path string
---@return boolean success
function ComponentFilesystem.makeDirectory(path) end

--- Returns a boolean some file exists
---@param path string
---@return boolean
function ComponentFilesystem.exists(path) end

--- Returns true if a filesystem is read only
---@return boolean readonly
function ComponentFilesystem.isReadOnly() end

--- Write a string into a file handle
---@param handle integer
---@param value string
---@return boolean success
function ComponentFilesystem.write(handle, value) end

--- Returns the total capacity of the filesystem
---@return integer
function ComponentFilesystem.spaceTotal() end

--- Returns true if the provided path points to a directory otherwise false
---@param path string
---@return boolean
function ComponentFilesystem.isDirectory(path) end

--- Rename a directory or file
---@param from string
---@param to string
---@return boolean success
function ComponentFilesystem.rename(from, to) end

--- List items at a path
---@param path string
---@return string[] items
function ComponentFilesystem.list(path) end

--- Returns a timestamp of the last time that the contents at thatbpath were modified
---@param path string
---@return integer date
function ComponentFilesystem.lastModified(path) end

--- Return the current label of this filesystem
---@return string label
function ComponentFilesystem.getLabel() end

--- Removes a item at the specified path
---@param path string
---@return boolean success
function ComponentFilesystem.remove(path) end

--- Close a file handle
---@param handle integer
function ComponentFilesystem.close(handle) end

--- Returns the size of an item at the specified path
---@param path string
---@return integer
function ComponentFilesystem.size(path) end

--- Read a chunk from a file handle
---@param handle integer
---@param amount integer
---@return string? data
function ComponentFilesystem.read(handle, amount) end

--- Change this filesystems label
---@param value string
---@return string label
function ComponentFilesystem.setLabel(value) end

--- GPU

--- Attempts to bind a screen to this GPU
---@param address string
---@param reset boolean?
---@return boolean ok
---@return string? error
function ComponentGPU.bind(address, reset) end

--- Returns the address of the attached screen
---@return string address
function ComponentGPU.getScreen() end

--- Returns the current background color
---@return integer color
---@return boolean isPalette
function ComponentGPU.getBackground() end

--- Set background color
---@param color integer
---@param isPaletteIndex boolean
---@return integer oldColor
function ComponentGPU.setBackground(color, isPaletteIndex) end

--- Gets foreground color
---@return integer color
---@return boolean isPalette
function ComponentGPU.getForeground() end

--- Sets foreground color
---@param color integer
---@param isPaletteIndex boolean
---@return integer oldColor
function ComponentGPU.setForeground(color, isPaletteIndex) end

--- Get the color at the palette index provided
---@param index integer
---@return integer color
function ComponentGPU.getPaletteColor(index) end

--- Set the color of a specific palette index 
---@param index integer
---@param value integer
---@return integer
function ComponentGPU.setPaletteColor(index, value) end

--- Returns the maximum color depth
---@return 8 | 4 | 1
function ComponentGPU.maxDepth() end

--- Gets the current color depth
---@return 8 | 4 | 1 depth
function ComponentGPU.getDepth() end

--- Set bit depth
---@param depth 8 | 4 | 1
---@return "EightBit" | "FourBit" | "OneBit" lastDepth
function ComponentGPU.setDepth(depth) end

--- Get the maximum resolution supported by this GPU
---@return integer width
---@return integer height
function ComponentGPU.maxResolution() end

--- Gets the current resolution
---@return integer width
---@return integer height
function ComponentGPU.getResolution() end

--- Set resolution
---@param width integer
---@param height integer
---@return boolean success
function ComponentGPU.setResolution(width, height) end

--- Return current viewport size
---@return integer width
---@return integer height
function ComponentGPU.getViewport() end

--- Set viewport size
---@param width integer
---@param height integer
---@return boolean success
function ComponentGPU.setViewport(width, height) end

--- Get the character, foreground, and background of a cell
---@param x integer
---@param y integer
---@return string char
---@return integer foreground
---@return integer background
---@return integer? foregroundIndex
---@return integer? backgroundIndex
function ComponentGPU.get(x, y) end

--- Draws a string to the screen
---@param x integer
---@param y integer
---@param value string
---@param vertical boolean?
---@return boolean success
function ComponentGPU.set(x, y, value, vertical) end

--- Copy a region of the screen to another portion
---@param x integer
---@param y integer
---@param width integer
---@param height integer
---@param tx integer
---@param ty integer
---@return boolean success
function ComponentGPU.copy(x, y, width, height, tx, ty) end

--- Fill a region
---@param x integer
---@param y integer
---@param width integer
---@param height integer
---@param char string
---@return boolean success
function ComponentGPU.fill(x, y, width, height, char) end

--- Internet

--- Checks if we can use TCP sockets
---@return boolean
function ComponentInternet.isTcpEnabled() end

--- Objects

--- Checks if we can make http requests
---@return boolean
function ComponentInternet.isHttpEnabled() end

---@class InternetTCPConnection : userdata
local InternetTCPConnection = {}

---@class InternetHTTPHandle : userdata
local InternetHTTPHandle = {}

--- Opens a TCP socket
---@param address string
---@param port integer?
---@return InternetTCPConnection
function ComponentInternet.connect(address, port) end

--- Send a HTTP request
---@param url string
---@param postData string?
---@param headers table<string, string>?
---@return InternetHTTPHandle
function ComponentInternet.request(url, postData, headers) end

--- TCP Socket

--- Read incoming data
---@param amount integer?
---@return string?
function InternetTCPConnection.read(amount) end

--- Close connection
function InternetTCPConnection.close() end

--- Write data to socket
---@param data string
---@return integer
function InternetTCPConnection.write(data) end

--- Ensure connection
---@return boolean
function InternetTCPConnection.finishConnect() end

--- Get socket id
---@return string
function InternetTCPConnection.id() end

--- HTTP request

--- Read a chunk from the HTTP handle
---@param amount integer
---@return string?
function InternetHTTPHandle.read(amount) end

--- Read response info
---@return integer code
---@return string message
---@return table<string, string> headers
function InternetHTTPHandle.response() end

--- Close handle
function InternetHTTPHandle.close() end

--- Ensure connection
---@return boolean
function InternetHTTPHandle.finishConnect() end

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
---@return string|integer
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
---@param index integer
---@param value any
---@param targets string|table
function checkArg(index, value, targets) end