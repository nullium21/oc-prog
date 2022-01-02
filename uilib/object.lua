---@class Object
local Object = {}
Object.meta = {__index = Object}

-- Create a new instance of this object
---@generic T
---@param self T
---@return T
function Object:create()
  local meta = rawget(self, "meta")
  if not meta then error("Cannot inherit from instance object") end
  return setmetatable({}, meta)
end

--[[
Creates a new instance and calls `obj:initialize(...)` if it exists.
```lua
    local Rectangle = Object:extend()
    function Rectangle:initialize(w, h)
      self.w = w
      self.h = h
    end
    function Rectangle:getArea()
      return self.w * self.h
    end
    local rect = Rectangle:new(3, 4)
    p(rect:getArea())
```
]]
---@generic T
---@param self T
---@return T
function Object:new(...)
  local obj = self:create()
  if type(obj.initialize) == "function" then
    obj:initialize(...)
  end
  return obj
end

---@type fun(...)
Object.initialize = nil

--[[
Creates a new sub-class.
```lua
    local Square = Rectangle:extend()
    function Square:initialize(w)
      self.w = w
      self.h = h
    end
```
]]
---@generic T
---@param self T
---@return T
function Object:extend()
  local obj = self:create()
  local meta = {}
  -- move the meta methods defined in our ancestors meta into our own
  --to preserve expected behavior in children (like __tostring, __add, etc)
  for k, v in pairs(self.meta) do
    meta[k] = v
  end
  meta.__index = obj
  meta.super=self
  obj.meta = meta
  return obj
end

return Object
