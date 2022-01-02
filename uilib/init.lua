local object = require("uilib.object")
local dbuf = require("uilib.dbuffer")
local util = require("uilib.util")

local event = require("event")

local screen_event_type = {
  touch = true, drag = true, drop = true, scroll = true, double_touch = true
}

---@class Ui
local ui = {}

--[[ Object ]] do
  ---@class Ui.Object: Object
  local _object = object:extend()

  ---@param x number
  ---@param y number
  ---@param w number
  ---@param h number
  function _object:initialize(x, y, w, h)
    self.x, self.y = x, y
    self.width, self.height = w, h
    self.visible = true

    ---@type Ui.Container
    self.parent = nil
    ---@type Ui.Container
    self.fst_parent = nil

    ---@type number
    self.local_x = nil
    ---@type number
    self.local_y = nil

    self.events_pass_through = true
    self.enabled = true
  end

  ---@generic T
  ---@param self T
  ---@return T
  function _object:draw()
    return self
  end

  ---@return number|nil
  function _object:index()
    if not self.parent then error "object doesn't have a parent" end

    local pch = self.parent.children
    for i = 1, #pch do
      if pch[i] == self then return i end
    end
  end

  function _object:forward()
    if not self.parent then error "object doesn't have a parent" end

    local i = self:index()
    if i < #self.parent.children then
      self.parent.children[i], self.parent.children[i+1] = self.parent.children[i+1], self
    end
  end

  function _object:backward()
    if not self.parent then error "object doesn't have a parent" end

    local i = self:index()
    if i > 1 then
      self.parent.children[i], self.parent.children[i-1] = self.parent.children[i-1], self
    end
  end

  function _object:to_front()
    if not self.parent then error "object doesn't have a parent" end

    table.remove(self.parent.children, self:index())
    table.insert(self.parent.children, 0, self)
  end

  function _object:to_back()
    if not self.parent then error "object doesn't have a parent" end

    table.remove(self.parent.children, self:index())
    table.insert(self.parent.children, #self.parent.children+1, self)
  end

  function _object:remove_from_parent()
    if not self.parent then error "object doesn't have a parent" end

    table.remove(self.parent.children, self:index())
  end

  ---@param app Ui.Application
  ---@param e any[]
  function _object:handle_event(app, e) end

  ui.object = _object
end

--[[ Container ]] do
  ---@class Ui.Container: Ui.Object
  local _container = ui.object:extend()

  function _container:fullscreen()
    return _container:new(1, 1, dbuf.getResolution())
  end

  ---@param x number
  ---@param y number
  ---@param w number
  ---@param h number
  function _container:initialize(x, y, w, h)
    ui.object.initialize(self, x, y, w, h)

    ---@type Ui.Object[]
    self.children = {}
  end

  ---@generic T
  ---@param self T
  ---@return T
  function _container:draw()
    local rx1, ry1, rx2, ry2 = dbuf.getDrawLimit()
    local ix1, iy1, ix2, iy2 = util.rect_intersect(rx1, ry1, rx2, ry2, self.x, self.y, self.x+self.width-1, self.y+self.height-1)

    if ix1 then
      dbuf.setDrawLimit(ix1, iy1, ix2, iy2)

      for i = 1, #self.children do
        local child = self.children[i]
        if child.visible then
          child.x, child.y = child.local_x + self.x - 1, child.local_y + self.y - 1
          child:draw()
        end
      end

      dbuf.setDrawLimit(rx1, ry1, rx2, ry2)
    end

    return self
  end

  ---@param child Ui.Object
  ---@param idx number|nil
  function _container:add(child, idx)
    child.local_x, child.local_y = child.x, child.y

    ---@param obj Ui.Object|Ui.Container
    ---@param p Ui.Container
    local function update_fstparent(obj, p)
      local to_update = { obj }
      while #to_update > 0 do
        ---@type Ui.Object|Ui.Container
        local it = table.remove(to_update, 1)
        if it.children then
          for i = 1, #it.children do
            table.insert(to_update, it.children[i])
          end
        end
      end
    end
    update_fstparent(child, self)

    if idx then
      table.insert(self.children, idx, child)
    else
      table.insert(self.children, child)
    end

    child.parent = self
  end

  ---@param i number
  ---@param j number|nil
  function _container:remove(i, j)
    j = j or i

    for k = i, j do
      table.remove(self.children, k)
    end
  end

  ui.container = _container
end

--[[ Application ]] do
  ---@class Ui.Application: Ui.Container
  local _application = ui.container:extend()

  ---@param x number
  ---@param y number
  ---@param w number
  ---@param h number
  function _application:initialize(x, y, w, h)
    x = x or 1
    y = y or 1
    w = w or select(1, dbuf.getResolution())
    h = h or select(1, dbuf.getResolution())

    ui.container.initialize(self, x, y, w, h)

    self.should_close = false
  end

  ---@param self Ui.Container
  ---@param app Ui.Application
  ---@param e any[]
  ---@param ix1 number
  ---@param iy1 number
  ---@param ix2 number
  ---@param iy2 number
  ---@return boolean
  local function handle_event(self, app, e, ix1, iy1, ix2, iy2)
    local is_scr_event = screen_event_type[e[1]] or false

    if (not is_scr_event) or (
      ix1 and e[3] >= ix1 and e[3] <= ix2 and e[4] >= iy1 and e[4] <= iy2
    ) then
      local passed = false
      local nx1, ny1, nx2, ny2

      if is_scr_event then
        if self.enabled then self:handle_event(app, e) end
        passed = not self.events_pass_through
      else
        self:handle_event(app, e)
      end

      for i = #self.children, 1, -1 do
        local child = self.children[i]

        if child.visible then
          if child.children then
            nx1, ny1, nx2, ny2 = util.rect_intersect(ix1, iy2, ix1, iy2, child.x, child.y, child.x+child.width-1, child.y+child.height-1)

            if nx1 and handle_event(child, app, nx1, ny1, nx2, ny2) then
              return true
            end
          else
            if is_scr_event then
              if e[3] >= child.x and e[3] <= child.x+child.width-1 and e[4] >= child.y and e[4] <= child.y+child.height-1 then
                child:handle_event(app, e)

                if not child.events_pass_through then return true end
              end
            else
              child:handle_event(app, e)
            end
          end
        end
      end

      if passed then return true end
    end
  end

  ---@param evpull_timeout number
  function _application:start(evpull_timeout)
    repeat
      local e = table.pack(event.pull(evpull_timeout))

      handle_event(self, self, e, self.x, self.y, self.x+self.width-1, self.y+self.height-1)

    until self.should_close
    self.should_close = false
  end

  function _application:stop()
    self.should_close = true
  end

  ---@param force_redraw boolean
  function _application:draw(force_redraw)
    ui.container.draw(self)
    dbuf.drawChanges(force_redraw)
  end

  ui.application = _application
end

-- return ui