local classes = require("classes")
local EventSystem = require("eventsystem")
local component = require("component")

local termbox = {}
termbox.defaultGpu = component.gpu

---@class FrameBuffer : classes
---@field gpu any
---@field buffer table
---@field dirty table<number, boolean>
---@field width number
---@field height number
---@field colorDepth number
---@field bound number
---@field foreground number
---@field background number
local FrameBuffer = classes.create("FrameBuffer")

termbox.FrameBuffer = FrameBuffer

--- Create a FrameBuffer
---@param width number?
---@param height number?
---@param colorDepth number?
---@param gpu any?
---@return FrameBuffer
function FrameBuffer:constructor(width, height, colorDepth, gpu)
  gpu = gpu or termbox.defaultGpu

  local gpuWidth, gpuHeight = gpu.getResolution()

  width = width or gpuWidth
  height = height or gpuHeight
  colorDepth = colorDepth or gpu.getDepth()

  local o = setmetatable({}, self)
  ---@cast o FrameBuffer

  o.gpu = gpu
  o.width = width
  o.height = height
  o.colorDepth = colorDepth

  -- Physical buffer represented by this framebuffer.
  -- -1 means virtual.
  o.bound = -1

  -- GPU state.
  o.background = 0x000000
  o.foreground = 0xffffff

  -- Dirty rows.
  o.dirty = {}

  -- Create framebuffer.
  o.buffer = {}

  for y = 1, height do
    o.buffer[y] = {}

    for x = 1, width do
      o.buffer[y][x] = {
        " ",
        o.background,
        o.foreground
      }
    end

    o.dirty[y] = true
  end

  return o
end


----------------------------------------------------------------
-- Internal helpers
----------------------------------------------------------------

function FrameBuffer:checkCellBounds(x, y)
  checkArg(1, x, "number")
  checkArg(2, y, "number")

  if x < 1 or y < 1 or x > self.width or y > self.height then
    errorf("Cell out of bounds (at %d, %d)", x, y, 2)
  end
end


function FrameBuffer:checkRect(x, y, width, height)
  if width < 0 or height < 0 then
    error("Width and height must be non-negative", 2)
  end

  if x < 1 or y < 1 or
     x + width - 1 > self.width or
     y + height - 1 > self.height then
    error("Rectangle out of bounds", 2)
  end
end


function FrameBuffer:markDirty(y)
  self.dirty[y] = true
end


----------------------------------------------------------------
-- Framebuffer
----------------------------------------------------------------

function FrameBuffer:setCell(x, y, bg, fg, char)
  self:checkCellBounds(x, y)

  local cell = self.buffer[y][x]

  local newChar = char or cell[1]
  local newBg = bg or cell[2]
  local newFg = fg or cell[3]

  -- Nothing actually changed.
  if cell[1] == newChar and
     cell[2] == newBg and
     cell[3] == newFg then
    return false
  end

  cell[1] = newChar
  cell[2] = newBg
  cell[3] = newFg

  self:markDirty(y)

  return true
end


function FrameBuffer:getCell(x, y, clone)
  self:checkCellBounds(x, y)

  local cell = self.buffer[y][x]

  if clone then
    return {
      cell[1],
      cell[2],
      cell[3]
    }
  end

  return cell
end


----------------------------------------------------------------
-- GPU state
----------------------------------------------------------------

function FrameBuffer:getBackground()
  return self.background
end


function FrameBuffer:setBackground(color)
  checkArg(1, color, "number")

  self.background = color

  return true
end


function FrameBuffer:getForeground()
  return self.foreground
end


function FrameBuffer:setForeground(color)
  checkArg(1, color, "number")

  self.foreground = color

  return true
end


function FrameBuffer:maxDepth()
  return 8
end


function FrameBuffer:getDepth()
  return self.colorDepth
end


function FrameBuffer:setDepth(level)
  checkArg(1, level, "number")

  assert(
    level == 1 or level == 4 or level == 8,
    "Unsupported bit depth " .. level
  )

  self.colorDepth = level

  return true
end


----------------------------------------------------------------
-- Resolution
----------------------------------------------------------------

function FrameBuffer:maxResolution()
  return math.huge, math.huge
end


function FrameBuffer:getResolution()
  return self.width, self.height
end


function FrameBuffer:setResolution(width, height)
  checkArg(1, width, "number")
  checkArg(2, height, "number")

  if width < 1 or height < 1 then
    error("Resolution must be at least 1x1", 2)
  end

  local buffer = {}
  local dirty = {}

  for y = 1, height do
    buffer[y] = {}

    for x = 1, width do
      buffer[y][x] = {
        " ",
        self.background,
        self.foreground
      }
    end

    dirty[y] = true
  end

  self.buffer = buffer
  self.dirty = dirty

  self.width = width
  self.height = height

  return true
end


----------------------------------------------------------------
-- GPU-like operations
----------------------------------------------------------------

function FrameBuffer:get(x, y)
  local cell = self:getCell(x, y)

  -- GPU get() returns:
  -- character, foreground, background
  return cell[1], cell[3], cell[2]
end


function FrameBuffer:set(x, y, string, vertical)
  checkArg(1, x, "number")
  checkArg(2, y, "number")
  checkArg(3, string, "string")

  if vertical then
    for i = 1, #string do
      self:setCell(
        x,
        y + i - 1,
        self.background,
        self.foreground,
        string:sub(i, i)
      )
    end
  else
    for i = 1, #string do
      self:setCell(
        x + i - 1,
        y,
        self.background,
        self.foreground,
        string:sub(i, i)
      )
    end
  end

  return true
end


function FrameBuffer:fill(x, y, width, height, char)
  checkArg(1, x, "number")
  checkArg(2, y, "number")
  checkArg(3, width, "number")
  checkArg(4, height, "number")

  char = char or " "

  self:checkRect(x, y, width, height)

  for row = y, y + height - 1 do
    for col = x, x + width - 1 do
      self:setCell(
        col,
        row,
        self.background,
        self.foreground,
        char
      )
    end
  end

  return true
end


function FrameBuffer:copy(x, y, width, height, tx, ty)
  checkArg(1, x, "number")
  checkArg(2, y, "number")
  checkArg(3, width, "number")
  checkArg(4, height, "number")
  checkArg(5, tx, "number")
  checkArg(6, ty, "number")

  self:checkRect(x, y, width, height)

  if tx < 1 or ty < 1 or
     tx + width - 1 > self.width or
     ty + height - 1 > self.height then
    error("Destination rectangle out of bounds", 2)
  end

  -- Snapshot first.
  -- This is important for overlapping copies.
  local temp = {}

  for row = 1, height do
    temp[row] = {}

    for col = 1, width do
      local cell = self.buffer[y + row - 1][x + col - 1]

      temp[row][col] = {
        cell[1],
        cell[2],
        cell[3]
      }
    end
  end

  -- Write snapshot.
  for row = 1, height do
    for col = 1, width do
      local cell = temp[row][col]

      self.buffer[ty + row - 1][tx + col - 1] = {
        cell[1],
        cell[2],
        cell[3]
      }
    end

    self:markDirty(ty + row - 1)
  end

  return true
end


----------------------------------------------------------------
-- Framebuffer cloning
----------------------------------------------------------------

function FrameBuffer:clone()
  local o = setmetatable({}, getmetatable(self))

  o.gpu = self.gpu
  o.width = self.width
  o.height = self.height
  o.colorDepth = self.colorDepth
  o.bound = self.bound
  o.foreground = self.foreground
  o.background = self.background

  o.buffer = {}
  o.dirty = {}

  for y = 1, self.height do
    o.buffer[y] = {}
    o.dirty[y] = false

    for x = 1, self.width do
      local cell = self.buffer[y][x]

      o.buffer[y][x] = {
        cell[1],
        cell[2],
        cell[3]
      }
    end
  end

  return o
end


----------------------------------------------------------------
-- Diff pipeline
----------------------------------------------------------------

function FrameBuffer:diff(previous)
  checkArg(1, previous, "table")

  if previous.width ~= self.width or
     previous.height ~= self.height then
    error("Framebuffer dimensions do not match", 2)
  end

  local operations = {}

  local function different(a, b)
    return a[1] ~= b[1]
        or a[2] ~= b[2]
        or a[3] ~= b[3]
  end

  for y = 1, self.height do

    -- We know this row cannot have changed.
    if not self.dirty[y] then
      goto continue
    end

    local x = 1

    while x <= self.width do
      local current = self.buffer[y][x]
      local old = previous.buffer[y][x]

      if different(current, old) then
        local start = x

        local fg = current[3]
        local bg = current[2]

        local text = {}

        while x <= self.width do
          current = self.buffer[y][x]
          old = previous.buffer[y][x]

          if not different(current, old) then
            break
          end

          if current[3] ~= fg or current[2] ~= bg then
            break
          end

          text[#text + 1] = current[1]

          x = x + 1
        end

        operations[#operations + 1] = {
          x = start,
          y = y,
          text = table.concat(text),
          foreground = fg,
          background = bg
        }
      else
        x = x + 1
      end
    end

    ::continue::
  end

  return operations
end


----------------------------------------------------------------
-- Render operations
----------------------------------------------------------------

function FrameBuffer:renderOperations(operations)
  local gpu = self.gpu

  local currentFg = nil
  local currentBg = nil

  for i = 1, #operations do
    local op = operations[i]

    if currentFg ~= op.foreground then
      gpu.setForeground(op.foreground)
      currentFg = op.foreground
    end

    if currentBg ~= op.background then
      gpu.setBackground(op.background)
      currentBg = op.background
    end

    gpu.set(op.x, op.y, op.text)
  end

  return true
end


----------------------------------------------------------------
-- Render
----------------------------------------------------------------

function FrameBuffer:render(previous)
  -- No previous frame means everything needs to be drawn.
  if not previous then
    previous = FrameBuffer:blank(
      self.width,
      self.height,
      self.colorDepth,
      self.gpu
    )
  end

  local operations = self:diff(previous)

  self:renderOperations(operations)

  return operations
end


----------------------------------------------------------------
-- Blank framebuffer
----------------------------------------------------------------

function FrameBuffer.blank(width, height, colorDepth, gpu)
  return FrameBuffer:new(
    width,
    height,
    colorDepth,
    gpu
  )
end

FrameBuffer.__mutates = {
  [FrameBuffer.setResolution] = true,
  [FrameBuffer.set] = true,
  [FrameBuffer.copy] = true,
  [FrameBuffer.fill] = true,

  [FrameBuffer.setCell] = true
}

-- termbox
---@class TermBoxWorld : classes
---@field boxes TermBox[]
---@field viewport {x: number, y: number, width: number, height: number}
---@field dirty boolean
---@field owners table<number, table<number, TermBox>>
---@field currentFrame FrameBuffer?
local TermBoxWorld = classes.create("TermBoxWorld")

termbox.TermBoxWorld = TermBoxWorld

--- Creates a TermBoxWorld.
---@param gpu any
---@param x number?
---@param y number?
---@param width number?
---@param height number?
---@return TermBoxWorld
function TermBoxWorld:constructor(gpu, x, y, width, height)
  local gpuWidth, gpuHeight = gpu.getResolution()

  x = x or 1
  y = y or 1
  width = width or gpuWidth
  height = height or gpuHeight

  if width < 1 or height < 1 then
    error("Viewport resolution must be at least 1x1", 2)
  end

  local o = setmetatable({
    gpu = gpu,
    boxes = {},
    dirty = true,
    owners = {},
    currentFrame = nil,
    viewport = {
      x = x,
      y = y,
      width = width,
      height = height
    }
  }, self)
  ---@cast o TermBoxWorld

  return o
end

--- Mark the world's composition as dirty.
function TermBoxWorld:markDirty()
  self.dirty = true
end

--- Add a TermBox to the world. Boxes are rendered back-to-front.
---@param box TermBox
---@return boolean
function TermBoxWorld:add(box)
  checkArg(1, box, "table")

  if box.world and box.world ~= self then
    error("TermBox already belongs to another world", 2)
  end

  for i = 1, #self.boxes do
    if self.boxes[i] == box then
      return false
    end
  end

  self.boxes[#self.boxes + 1] = box
  box.world = self
  box.dirty = true
  self:markDirty()

  return true
end

--- Remove a TermBox from the world.
---@param box TermBox
---@param force boolean?
---@return boolean
function TermBoxWorld:remove(box, force)
  checkArg(1, box, "table")

  for i = 1, #self.boxes do
    if self.boxes[i] == box then
      if box.onRemoving and not force then
        if not box:onRemoving() then -- allows persistent boxes
          table.remove(self.boxes, i)
        end
      else 
        table.remove(self.boxes, i)
      end
      

      if box.world == self then
        box.world = nil
      end

      self:markDirty()
      return true
    end
  end

  return false
end

--- Move a box to a new z-order position.
--- Position 1 is the back; #boxes is the front.
---@param box TermBox
---@param position number
---@return boolean
function TermBoxWorld:setOrder(box, position)
  checkArg(1, box, "table")
  checkArg(2, position, "number")

  local oldPosition

  for i = 1, #self.boxes do
    if self.boxes[i] == box then
      oldPosition = i
      break
    end
  end

  if not oldPosition then
    return false
  end

  position = math.floor(position)
  position = math.max(1, math.min(position, #self.boxes))

  if oldPosition == position then
    return false
  end

  table.remove(self.boxes, oldPosition)
  table.insert(self.boxes, position, box)

  self:markDirty()
  return true
end

--- Return the topmost TermBox owning a world-space cell.
---@param x number
---@param y number
---@return TermBox?
function TermBoxWorld:ownerAt(x, y)
  checkArg(1, x, "number")
  checkArg(2, y, "number")

  local row = self.owners[y]
  return row and row[x] or nil
end

--- Test whether a world-space point intersects a TermBox.
---@param box TermBox
---@param x number
---@param y number
---@return boolean
function TermBoxWorld:intersects(box, x, y)
  return x >= box.x
     and x < box.x + box.width
     and y >= box.y
     and y < box.y + box.height
end

--- Calculate the portion of a box visible inside the viewport.
---@param box TermBox
---@return number?, number?, number?, number?
function TermBoxWorld:intersection(box)
  local viewport = self.viewport

  local left = math.max(box.x, viewport.x)
  local top = math.max(box.y, viewport.y)
  local right = math.min(
    box.x + box.width - 1,
    viewport.x + viewport.width - 1
  )
  local bottom = math.min(
    box.y + box.height - 1,
    viewport.y + viewport.height - 1
  )

  if left > right or top > bottom then
    return nil
  end

  return left, top, right, bottom
end

--- Build the world-space ownership map.
---
--- Boxes are processed back-to-front, so the last box covering a cell becomes
--- its owner. The map is kept in world coordinates for event/hit-test routing.
---@return table<number, table<number, TermBox>>
function TermBoxWorld:buildOwners()
  local owners = {}

  for _, box in ipairs(self.boxes) do
    local left, top, right, bottom = self:intersection(box)

    if left then
      for y = top, bottom do
        local row = owners[y]

        if not row then
          row = {}
          owners[y] = row
        end

        for x = left, right do
          row[x] = box
        end
      end
    end
  end

  self.owners = owners
  return owners
end

--- Generate the composed framebuffer and owner map.
---
--- The framebuffer uses coordinates local to the viewport. The owner map
--- uses world-space coordinates so it can also be used for event routing.
---@return FrameBuffer frame
---@return table<number, table<number, TermBox>> owners
function TermBoxWorld:frame()
  local viewport = self.viewport

  if self.dirty then
    self:buildOwners()
    self.dirty = false
  end

  local frame = FrameBuffer.blank(
    viewport.width,
    viewport.height,
    self.gpu.getDepth(),
    self.gpu
  )

  for screenY = 1, viewport.height do
    local worldY = viewport.y + screenY - 1
    local ownersRow = self.owners[worldY]

    if ownersRow then
      for screenX = 1, viewport.width do
        local worldX = viewport.x + screenX - 1
        local box = ownersRow[worldX]

        if box then
          local localX = worldX - box.x + 1
          local localY = worldY - box.y + 1
          local cell = box.buffer:getCell(localX, localY)

          frame:setCell(
            screenX,
            screenY,
            cell[2],
            cell[3],
            cell[1]
          )
        end
      end
    end
  end

  self.currentFrame = frame
  return frame, self.owners
end

--- Render the composed world against a previous composed frame.
---@param previous FrameBuffer?
---@return FrameBuffer frame
---@return table operations
---@return table<number, table<number, TermBox>> owners
function TermBoxWorld:render(previous)
  local frame, owners = self:frame()
  local operations = frame:render(previous)

  for _, box in ipairs(self.boxes) do
    box.dirty = false
  end

  return frame, operations, owners
end

--- Set the world-space viewport.
---@param x number
---@param y number
---@param width number
---@param height number
---@return boolean
function TermBoxWorld:setViewport(x, y, width, height)
  checkArg(1, x, "number")
  checkArg(2, y, "number")
  checkArg(3, width, "number")
  checkArg(4, height, "number")

  if width < 1 or height < 1 then
    error("Viewport resolution must be at least 1x1", 2)
  end

  if self.viewport.x == x and
     self.viewport.y == y and
     self.viewport.width == width and
     self.viewport.height == height then
    return false
  end

  self.viewport.x = x
  self.viewport.y = y
  self.viewport.width = width
  self.viewport.height = height

  self:markDirty()
  return true
end

---@class TermBox : classes
---@field x number
---@field y number
---@field width number
---@field height number
---@field gpu any
---@field buffer FrameBuffer
---@field dirty boolean
---@field world TermBoxWorld?
---@field events EventSystem
local TermBox = classes.create("TermBox")

termbox.TermBox = TermBox

--- Create a TermBox.
---@param x number
---@param y number
---@param width number
---@param height number
---@param gpu any
---@return TermBox
function TermBox:constructor(x, y, width, height, gpu)
  checkArg(1, x, "number")
  checkArg(2, y, "number")
  checkArg(3, width, "number")
  checkArg(4, height, "number")

  if width < 1 or height < 1 then
    error("TermBox resolution must be at least 1x1", 2)
  end

  local buffer = FrameBuffer:new(width, height, nil, gpu)
  ---@cast buffer FrameBuffer

  local o = setmetatable({}, self)
  ---@cast o TermBox

  o.x = x
  o.y = y
  o.width = width
  o.height = height
  o.gpu = gpu
  o.buffer = buffer
  o.dirty = true
  o.world = nil

  local events = EventSystem:new()
  ---@cast events EventSystem
  o.events = events

  return o
end

----------------------------------------------------------------
-- TermBox state
----------------------------------------------------------------

--- Mark this box's contents/geometry as dirty.
---@param composition boolean? Also invalidate the world's owner map.
function TermBox:markDirty(composition)
  self.dirty = true

  if composition and self.world then
    self.world:markDirty()
  end
end

--- Set the box's world-space position.
---@param x number
---@param y number
---@return boolean
function TermBox:setPosition(x, y)
  checkArg(1, x, "number")
  checkArg(2, y, "number")

  if self.x == x and self.y == y then
    return false
  end

  self.x = x
  self.y = y
  self:markDirty(true)

  return true
end

-- events

function TermBox:invoke(name, ...)
  self.events:invoke(name, ...)
end

function TermBox:on(name, callback)
  self.events:on(name, callback)
end

function TermBox:remove(name, callback)
  self.events:remove(name, callback)
end
--- Set the box's size and resize its underlying framebuffer.
---@param width number
---@param height number
---@return boolean
function TermBox:setResolution(width, height)
  checkArg(1, width, "number")
  checkArg(2, height, "number")

  if width == self.width and height == self.height then
    return false
  end

  self.buffer:setResolution(width, height)
  self.width = width
  self.height = height
  self:markDirty(true)

  if self.onResize then
    self:onResize(width, height)
  end

  return true
end

--- Return the box's world-space rectangle.
---@return number x
---@return number y
---@return number width
---@return number height
function TermBox:getBounds()
  return self.x, self.y, self.width, self.height
end

--- Return the underlying framebuffer.
---@return FrameBuffer
function TermBox:getBuffer()
  return self.buffer
end

----------------------------------------------------------------
-- TermBox framebuffer forwarding
----------------------------------------------------------------

--- Forward a mutating framebuffer operation and dirty the box if it changed.
---@param name string
---@param ... any
---@return any
function TermBox:_forwardMutating(name, ...)
  local method = self.buffer[name]

  if not method then
    error("Unknown framebuffer method: " .. tostring(name), 2)
  end

  local result = method(self.buffer, ...)

  if result then
    self:markDirty(true)
  end

  return result
end

--- Forward a read-only framebuffer operation.
---@param name string
---@param ... any
---@return any
function TermBox:_forward(name, ...)
  local method = self.buffer[name]

  if not method then
    error("Unknown framebuffer method: " .. tostring(name), 2)
  end

  return method(self.buffer, ...)
end

function TermBox:get(x, y)
  return self:_forward("get", x, y)
end

function TermBox:set(x, y, string, vertical)
  return self:_forwardMutating("set", x, y, string, vertical)
end

function TermBox:fill(x, y, width, height, char)
  return self:_forwardMutating("fill", x, y, width, height, char)
end

function TermBox:copy(x, y, width, height, tx, ty)
  return self:_forwardMutating("copy", x, y, width, height, tx, ty)
end

function TermBox:getBackground()
  return self:_forward("getBackground")
end

function TermBox:setBackground(color)
  return self:_forwardMutating("setBackground", color)
end

function TermBox:getForeground()
  return self:_forward("getForeground")
end

function TermBox:setForeground(color)
  return self:_forwardMutating("setForeground", color)
end

function TermBox:maxDepth()
  return self:_forward("maxDepth")
end

function TermBox:getDepth()
  return self:_forward("getDepth")
end

function TermBox:setDepth(level)
  return self:_forwardMutating("setDepth", level)
end

function TermBox:maxResolution()
  return self:_forward("maxResolution")
end

function TermBox:getResolution()
  return self:_forward("getResolution")
end

function TermBox:getCell(x, y, clone)
  return self:_forward("getCell", x, y, clone)
end

function TermBox:setCell(x, y, bg, fg, char)
  return self:_forwardMutating("setCell", x, y, bg, fg, char)
end

return termbox