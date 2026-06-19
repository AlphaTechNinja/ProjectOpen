local classes = require("classes")

local Program = classes.create("ProjectOpenEditorProgram")

local function cloneTokens(tokens)
    local out = {}
    for i = 1, #tokens do
        out[i] = tokens[i]
    end
    return out
end

local function sortByLocation(tokens)
    table.sort(tokens, function(a, b)
        return (a.location or 1) < (b.location or 1)
    end)
end

function Program:constructor(buffer, tokens)
    local o = setmetatable({
        buffer = buffer or "",
        tokens = cloneTokens(tokens or {}),
        dirty = false
    }, self)
    sortByLocation(o.tokens)
    return o
end

function Program:markDirty(state)
    if state == nil then
        state = true
    end
    self.dirty = not not state
    return self
end

function Program:setBuffer(buffer)
    self.buffer = tostring(buffer or "")
    return self:markDirty(true)
end

function Program:addToken(token)
    assert(type(token) == "table", "token expected")
    self.tokens[#self.tokens + 1] = token
    sortByLocation(self.tokens)
    return token
end

function Program:setTokens(tokens)
    assert(type(tokens) == "table", "tokens expected")
    self.tokens = cloneTokens(tokens)
    sortByLocation(self.tokens)
    return self:markDirty(true)
end

function Program:getTokenAt(position)
    for i = 1, #self.tokens do
        local token = self.tokens[i]
        if token:contains(position) then
            return token, i
        end
    end
    return nil
end

function Program:getTokenIndex(token)
    for i = 1, #self.tokens do
        if self.tokens[i] == token then
            return i
        end
    end
    return nil
end

function Program:rebuildBuffer()
    local pieces = {}
    local cursor = 1
    sortByLocation(self.tokens)

    for i = 1, #self.tokens do
        local token = self.tokens[i]
        local location = math.max(1, math.floor(token.location or 1))
        if location > cursor then
            pieces[#pieces + 1] = self.buffer:sub(cursor, location - 1)
        end
        pieces[#pieces + 1] = token.contents or ""
        cursor = location + #(token.contents or "")
    end

    if cursor <= #self.buffer then
        pieces[#pieces + 1] = self.buffer:sub(cursor)
    end

    self.buffer = table.concat(pieces)
    self:markDirty(true)
    return self.buffer
end

function Program:applyEdit(edit)
    assert(type(edit) == "table", "edit table expected")
    local location = math.max(1, math.floor(edit.location or 1))
    local delta = tonumber(edit.delta) or 0

    local left = self.buffer:sub(1, location - 1)
    if edit.kind == "insert" then
        self.buffer = left .. tostring(edit.text or "") .. self.buffer:sub(location)
    elseif edit.kind == "remove" then
        local removeLen = math.max(0, tonumber(edit.length) or math.abs(delta))
        self.buffer = left .. self.buffer:sub(location + removeLen)
    else
        error("unknown edit kind '" .. tostring(edit.kind) .. "'", 2)
    end

    for i = 1, #self.tokens do
        local token = self.tokens[i]
        if token ~= edit.token and token.location > location then
            token:shift(delta)
        elseif token ~= edit.token and token:contains(location) then
            token:setDirty(true)
        end
    end

    self:markDirty(true)
    return self
end

function Program:insertAt(position, text)
    local token, index = self:getTokenAt(position)
    if token then
        local edit = token:insertText(position - token.location + 1, text)
        return self:applyEdit(edit)
    end

    local edit = {
        kind = "insert",
        location = position,
        delta = #(text or ""),
        text = text,
        token = nil
    }
    return self:applyEdit(edit)
end

function Program:removeAt(position, length)
    local token, index = self:getTokenAt(position)
    if token then
        local edit = token:removeText(position - token.location + 1, length)
        return self:applyEdit(edit)
    end

    local edit = {
        kind = "remove",
        location = position,
        delta = -(tonumber(length) or 1),
        length = tonumber(length) or 1,
        token = nil
    }
    return self:applyEdit(edit)
end

function Program:tokenize(tokenizer, options)
    assert(type(tokenizer) == "table", "tokenizer expected")
    if tokenizer.tokenizeProgram then
        return tokenizer:tokenizeProgram(self, options)
    end
    if tokenizer.tokenize then
        self.tokens = tokenizer:tokenize(self.buffer, options)
        sortByLocation(self.tokens)
        return self:markDirty(true)
    end
    error("tokenizer does not implement tokenizeProgram or tokenize", 2)
end

function Program:__tostring()
    return self.buffer
end

return Program
