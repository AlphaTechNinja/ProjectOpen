local classes = require("classes")

local Token = classes.create("ProjectOpenEditorToken")

local function clamp(n, low, high)
    if n < low then return low end
    if n > high then return high end
    return n
end

function Token:constructor(kind, contents, location, dirty)
    return setmetatable({
        type = kind or "text",
        contents = contents or "",
        location = location or 1,
        dirty = dirty or false
    }, self)
end

function Token:getEnd()
    return self.location + #self.contents - 1
end

function Token:setDirty(state)
    if state == nil then
        state = true
    end
    self.dirty = not not state
    return self
end

function Token:shift(delta)
    self.location = math.max(1, self.location + (delta or 0))
    return self
end

function Token:setContents(contents)
    self.contents = tostring(contents or "")
    return self:setDirty(true)
end

function Token:insertText(offset, text)
    text = tostring(text or "")
    offset = clamp(math.floor(offset or (#self.contents + 1)), 1, #self.contents + 1)

    local left = self.contents:sub(1, offset - 1)
    local right = self.contents:sub(offset)
    self.contents = left .. text .. right
    self.dirty = true

    return {
        kind = "insert",
        token = self,
        location = self.location + offset - 1,
        delta = #text,
        text = text
    }
end

function Token:removeText(offset, length)
    offset = clamp(math.floor(offset or 1), 1, #self.contents + 1)
    length = math.max(0, math.floor(length or 1))

    local removed = self.contents:sub(offset, offset + length - 1)
    local left = self.contents:sub(1, offset - 1)
    local right = self.contents:sub(offset + length)
    self.contents = left .. right
    self.dirty = true

    return {
        kind = "remove",
        token = self,
        location = self.location + offset - 1,
        delta = -#removed,
        removed = removed,
        length = #removed
    }
end

function Token:contains(position)
    return position >= self.location and position <= self:getEnd()
end

function Token:__tostring()
    return self.contents
end

return Token
