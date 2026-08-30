local termbox = require("termbox")
local io = require("io")
local poll = require("poll")
local component = require("component")
local event = require("event")
local Async = require("async")
local EventSystem = require("eventsystem")

local term = {}
term.cursor = {
    x = 1,
    y = 1
}
term.gpu = component.gpu
termbox.defaultGpu = term.gpu

local eventsystem = EventSystem:new()
---@cast eventsystem EventSystem

--- Register terminal callback
---@param name string
---@param callback EventHandle
term.on = function (name, callback)
    eventsystem:on(name, callback)
end

--- Remove a terminal callback
---@param name string
---@param callback EventHandle
term.remove = function (name, callback)
    eventsystem:remove(name, callback)
end

local workspace = termbox.TermBoxWorld:new(term.gpu)
---@cast workspace TermBoxWorld
term.workspace = workspace
-- redraw initally
term.workspace:frame():render(nil)

function term.redraw()
    local last = term.workspace.currentFrame

    term.workspace:render(last)
end

function term._check()
    if term.workspace.dirty then
        term.redraw()
        term.workspace.dirty = false
    end
end

function term._ensureCursorVisible()
    local viewport = workspace.viewport
    local cursor = term.cursor

    if cursor.x < viewport.x then
        viewport.x = cursor.x
    elseif cursor.x >= viewport.x + viewport.width then
        viewport.x = cursor.x - viewport.width + 1
    end

    if cursor.y < viewport.y then
        viewport.y = cursor.y
    elseif cursor.y >= viewport.y + viewport.height then
        viewport.y = cursor.y - viewport.height + 1
    end
end

function term.propagate(x, y, eventname, ...)
    --- check for owner at position
    local owner = term.workspace:ownerAt(x, y)
    if owner then
        owner:invoke(eventname, ...)
        return true
    end

    eventsystem:invoke("missed", eventname, ...) -- missed
    return false
end

--- Clear terminal

function term.clear()
    term.workspace.boxes = {}
    term.workspace.dirty = true
    -- don't redraw immediantly (may be called from a thread so redraw async)
end

--- Box creation

function term.newBox(x, y, width, height)
    x = x or term.cursor.x
    y = y or term.cursor.y
    width = width or term.workspace.viewport.width
    height = height or 1 -- by default takes 1 line

    local box = termbox.TermBox:new(x, y, width, height)
    ---@cast box TermBox
    term.workspace:add(box)

    return box
end
