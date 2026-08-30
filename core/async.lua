-- allows promise like objects
local poller = require("poll")
local classes = require("classes")

---@class Async<T> : classes
---@field _state "pending"|"resolved"|"rejected"
---@field _waiters [{co : thread, key : any}]
local Async = classes.create("Async")

--- Create a Async object
---@generic T
---@param body fun(self : Async, res : fun(... : any), rej : fun(... : any))
---@return Async<T>
function Async:constructor(body)
  local o = setmetatable({_body = body, _state = "pending", _waiters = {}}, self)
  ---@cast o Async
  -- run body async
  local bodyCo = coroutine.wrap(body)
  bodyCo(o, function (...) return o:resolve(...) end, function (...) return o:reject(...) end)
  
  return o
end

--- Resolve
---@param ... any
function Async:resolve(...)
  if self:completed() then
    error("Can not resolve an already finished Async object", 2)
  end
  self._state = "resolved"
  self._results = {...}
  
  repeat
    local waiter = table.remove(self._waiters)
    poller.resumeLocked(waiter.co, nil, waiter.key, true, ...)
  until #self._waiters == 0 
end

--- Reject
---@param ... any
function Async:reject(...)
  if self:completed() then
    error("Can not reject an already finished Async object", 2)
  end
  self._state = "rejected"
  self._results = {...}
  
  repeat
    local waiter = table.remove(self._waiters)
    poller.resumeLocked(waiter.co, nil, waiter.key, false, ...)
  until #self._waiters == 0 
end

--- Check completion status
function Async:completed()
  return self._state ~= "pending"
end
-- methods

--- Await a async
---@generic T
---@param self Async<T>
---@return T
function Async:await()
  if self._state ~= "pending" then
    return table.unpack(self.results)
  end
  
  local results = {poller.yieldLocked(function (key)
    local current = coroutine.running()
    self._waiters[#self._waiters + 1] = {
      co = current,
      key = key
    }
  end)}
  
  local ok = table.remove(results, 1)
  if not ok then
    error(results[1], 2)
  else
    return table.unpack(results)
  end
end

--- Runs body after completion and returns a new Async for it
---@generic A
---@generic B
---@param self Async<A>
---@param body fun(value: A): B
---@return Async<B>
function Async:after(body)
  return Async:new(function (res, rej)
    local results = {pcall(self.await, self)}
    local ok = table.remove(results, 1)
    if ok then
      return res(body(table.unpack(results)))
    else
      rej(table.unpack(results))
    end
  end)
end

--- Creates a new Async that captures rejections
---@generic T
---@param body fun(... : any) : T
---@return Async<T>
function Async:catch(body)
  return Async:new(function (res, rej)
    local results = {pcall(self.await, self)}
    local ok = table.remove(results, 1)
    if ok then
      res(table.unpack(results))
    else
      local bodyRes = {pcall(body, tagle.unpack(results))}
      local bodyOk = table.remove(bodyRes, 1)
      if bodyOk then
        res(table.unpack(bodyRes))
      else
        rej(bodyRes[1])
      end
    end
  end)
end

-- helpers

--- Waits for all passed Async objects
---@param ... : Async
---@return [any]
function Async:all(...)
  local asyncs = {...}
  return Async:new(function (res, rej)
    local results = {}
    for i=1, #asyncs do
      local async = asyncs[i]
      local asyncResults = {pcall(async.await, async)}
      local asyncOk = table.remove(asyncResults, 1)
      if asyncOk then
        rej(table.unpack(asyncResults))
      else
        results[i] = asyncResults
      end
    end
    res(results)
  end)
end

--- Waits for any Async to finish
---@param ... : Async
---@return any
function Async:race(...)
  local asyncs = {...}
  return Async:new(function (res, rej)
    for i=1, #asyncs do
      local async = asyncs[i]
      async:after(function (results)
        if not self:completed() then
          res(table.unpack(results))
        end
      end)
      async:catch(function (results)
        if not self:completed() then
          rej(table.unpack(results))
        end
      end)
    end
  end)
end

return Async