-- fully loads term
local gpu = component.gpu
local io = require("io")
local basicTerm = require("term")
local event = require("event")
local polling = require("poll")
local term = {}
term.cursor = {
    x=1,
    y=1
}
term.__lastblinkpos = term.cursor
term.__isreading = false
term.__readqueue = {}
term.__readbuffer = ""
term.__lastreadbuffer = "" -- for backspace rendering properly
term.__blinkstate = false
term.__blinkEnabled = true
term.__blinkpos = nil
local function flip(x, y)
    local char, fg, bg = gpu.get(x, y)
    if not char then return end
    local oldfg, oldbg = gpu.getForeground(), gpu.getBackground()
    gpu.setBackground(fg)
    gpu.setForeground(bg)
    gpu.set(x, y, char)
    gpu.setBackground(oldbg)
    gpu.setForeground(oldfg)
end
function term.__updateBlink()
    local x, y = term.cursor.x, term.cursor.y
    if term.__readstart then
        x, y = term.__readstart.x + #term.__readbuffer, term.__readstart.y
    end

    if term.__blinkstate and term.__blinkpos then
        flip(term.__blinkpos.x, term.__blinkpos.y)
        term.__blinkstate = false
    end

    if term.__blinkEnabled then
        flip(x, y)
        term.__blinkstate = true
        term.__blinkpos = { x = x, y = y }
    else
        term.__blinkpos = nil
    end
end
function term.__resetblink()
    if term.__blinkstate and term.__blinkpos then
        flip(term.__blinkpos.x, term.__blinkpos.y)
        term.__blinkstate = false
        term.__blinkpos = nil
    end
end
function term.setBlink(mode)
    term.__blinkEnabled = mode
end
function term.blinkEnabled()
    term.setBlink(true)
end
function term.blinkDisabled()
    term.setBlink(false)
end
function term.newline()
    term.cursor.x = 1
    term.cursor.y = term.cursor.y + 1
    local w,h = gpu.getResolution()
    if term.cursor.y > h then
        term.cursor.y = h
        gpu.copy(1, 2, w, h - 1, 0, -1)
        gpu.fill(1, h, w, 1, " ")
    end
end
function term.clear()
    term.cursor = {x=1,y=1}
    local w,h = gpu.getResolution()
    gpu.setForeground(0xFFFFFF)
    gpu.setBackground(0x000000)
    gpu.fill(1,1,w,h," ")
end
function term.write(text)
    text = tostring(text)
    local screenWidth, screenHeight = gpu.getResolution()

    for i = 1, #text do
        local ch = text:sub(i,i)
        local byte = ch:byte()

        if byte == 10 then -- \n
            term.newline()
        elseif byte == 13 then
            -- Ignore \r (optional: handle \r\n combo by skipping next char)
        else
            gpu.set(term.cursor.x, term.cursor.y, ch)
            term.cursor.x = term.cursor.x + 1
            if term.cursor.x > screenWidth then
                term.newline()
                term.cursor.x = 1
            end
        end
    end
end

function term.__handleread()
    -- handles the read
    if term.__isreading then
        if not term.__readstart then
            term.__readstart = {x=term.cursor.x,y=term.cursor.y}
        end
        term.cursor = {x=term.__readstart.x,y=term.__readstart.y} -- this is fine we don't do any object checking here
        term.write(string.rep(" ",#term.__lastreadbuffer))
        term.cursor = {x=term.__readstart.x,y=term.__readstart.y}
        term.write(term.__readbuffer)
        term.__lastreadbuffer = term.__readbuffer
    else
        term.__readstart = nil
    end
end
event.listen("key_down", function(_, char, code)
    --io.stdout:write("key_down "..code)
    if code == 28 and term.__isreading then -- Enter
        term.__isreading = false
    elseif code == 14 and term.__isreading then -- Backspace
        term.__readbuffer = term.__readbuffer:sub(1, -2)
    elseif term.__isreading then
        if char >= 32 and char <= 126 or char == 9 then
            term.__readbuffer = term.__readbuffer .. string.char(char)
        end
    end
    term.__resetblink()
end)

function term.read()
    -- wait our turn if another program is using it
    while term.__isreading do
        coroutine.yield()
    end
    -- ok now we go
    term.__isreading = true
    --io.stdout:write("started read")
    while term.__isreading do
        coroutine.yield()
    end
    local data = term.__readbuffer
    term.__readbuffer = ""
    term.__lastreadbuffer = ""
    term.newline()
    return data
end

function term.setBlinkPeriod(time)
    checkArg(1,time,"number")
    term.__blinktime = time
end
term.__lastblink = computer.uptime()
 polling.register(function ()
    if computer.uptime() > term.__lastblink + (term.__blinktime or 1) then
        term.__lastblink = computer.uptime()
        term.__updateBlink()
    end
    term.__handleread()
end,"term")
-- io.stdout override
io.stdout.write = function (self,data)
    local pipe = self.__writepipe or self.__pipewrite
    if pipe then
        pipe:write(data)
        return
    end
    term.write(data)
end
io.stdin.read = function (self)
    local pipe = self.__readpipe or self.__piperead
    if pipe then
        return pipe:read()
    end
    return term.read()
end
return term
