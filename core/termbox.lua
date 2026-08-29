-- this is a completely different way to render
local classes = require("classes")
local io = require("io")
local event = require("event")
local poll = require("poll")

---@class TerminalBox : classes
local TerminalBox = classes.create("TerminalBox")

function TerminalBox:constructor(x, y, w ,h)
  local o = {
    boxes = {},
    viewport = {
      x = x,
      y = y,
      w = w,
      h = h
    },
    framebuffer = {}
  }
  return setmetatable(o, self)
end

function TerminalBox:refresh()
  -- clears framebuffer and redraws
end

function TerminalBox:redraw(gpu)
  -- TODO: implement
end

return {
  TermianlBox = TerminalBox
}