local object = require("uilib.object")
local dbuf = require("uilib.dbuffer")
local util = require("uilib.util")

local event = require("event")

local screen_event_type = {
  touch = true, drag = true, drop = true, scroll = true, double_touch = true
}

---@class Ui
local ui = {}

--[[ Alignment ]] do
  ---@alias Ui.Alignment "'start'"|"'center'"|"'end'"

  ---@param off number
  ---@param container_len number
  ---@param align Ui.Alignment
  ---@param obj_len number
  function ui.align_axis(off, container_len, align, obj_len)
    if align == 'start' then
      return off
    elseif align == 'center' then
      return off + (container_len - obj_len) / 2
    else
      return off + (container_len - obj_len)
    end
  end

  ---@param x number
  ---@param y number
  ---@param container_w number
  ---@param container_h number
  ---@param align_x Ui.Alignment
  ---@param align_y Ui.Alignment
  ---@param obj_w number
  ---@param obj_h number
  ---@return number, number
  function ui.align(x, y, container_w, container_h, align_x, align_y, obj_w, obj_h)
    return ui.align_axis(x, container_w, align_x, obj_w),
           ui.align_axis(y, container_h, align_y, obj_h)
  end
end

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

--[[ Label ]] do
  ---@class Ui.Label: Ui.Object
  local _label = ui.object:extend()

  ---@class Ui.Label.Args
  ---@field public align_x Ui.Alignment
  ---@field public align_y Ui.Alignment
  ---@field public fg_color number
  ---@field public bg_color number

  ---@param text string
  ---@param args Ui.Label.Args
  ---@param x number
  ---@param y number
  ---@param w number
  ---@param h number
  function _label:initialize(text, args, x, y, w, h)
    ui.object.initialize(self, x, y, w, h)

    self.text = text

    ---@type Ui.Alignment
    self.align_x = args.align_x or 'start'
    ---@type Ui.Alignment
    self.align_y = args.align_x or 'start'

    self.fg_color = args.fg_color
    self.bg_color = args.bg_color
  end

  function _label:draw()
    local wrapped_text, text_w, text_h =
      util.measure_and_wrap_text(self.text, self.width, self.height)

    local text_x, text_y = ui.align(
      self.x, self.y,
      self.width, self.height,
      self.align_x, self.align_y,
      text_w, text_h)

    if self.bg_color then
      dbuf.drawRectangle(self.x, self.y, self.width, self.height, self.bg_color, self.fg_color, ' ')
    end
    
    for i, line in ipairs(wrapped_text) do
      dbuf.drawText(math.floor(text_x), math.floor(text_y), self.fg_color, line)
      text_y = text_y + 1
    end
  end

  ui.label = _label
end

--[[ Grid ]] do
  ---@class Ui.Grid: Ui.Container
  local _grid = ui.container:extend()

  ---@class Ui.Layout.Args
  ---@field public num_rows integer
  ---@field public num_cols integer
  ---@field public spacing  integer
  ---@field public row_h    integer|integer[] @-1 (default) for dynamic
  ---@field public col_w    integer|integer[] @-1 (default) for dynamic

  ---@param args Ui.Layout.Args
  ---@param x number
  ---@param y number
  ---@param w number
  ---@param h number
  function _grid:initialize(args, x, y, w, h)
    ui.container.initialize(self, x, y, w, h)

    self.default_row = 1
    self.default_col = 1

    self.num_rows = args.num_rows or 1
    self.num_cols = args.num_cols or 1
    self.spacing  = args.spacing  or 0

    args.row_h = args.row_h or -1
    args.col_w = args.col_w or -1

    ---`[child_idx]=row,col`
    ---@type integer[][]
    self.child_positions = {}

    if type(args.row_h) == 'number' then
      self.row_h = {}
      for i = 1, self.num_rows do self.row_h[i] = args.row_h end
    else
      ---@type integer[]
      self.row_h = args.row_h
    end

    if type(args.col_w) == 'number' then
      self.col_w = {}
      for i = 1, self.num_cols do self.col_w[i] = args.col_w end
    else
      ---@type integer[]
      self.col_w = args.col_w
    end
  end

  ---@param child Ui.Object
  ---@param row number
  ---@param col number
  function _grid:set(child, row, col)
    local is_added, idx = pcall(child.index, child)
    if not is_added then idx = #self.children; table.insert(self.children, child) end

    self.child_positions[idx] = { row, col }
  end

  ---@param self Ui.Grid
  ---@param lst integer[]
  ---@param all_childs Ui.Object[][]
  ---@param param string
  ---@param num integer
  local function fix_line_param(self, lst, all_childs, param, num)
    for i = 1, num do
      local max = lst[i]
      local childs = all_childs[i]
      for _, child in ipairs(childs) do
        if child[param] > max then max = child[param] end
      end
      lst[i] = max
    end
  end

  function _grid:update_sizes()
    local row_c, col_c = {}, {}

    for i, pos in ipairs(self.child_positions) do
      local r, c = table.unpack(pos)
      if not row_c[r] then row_c[r] = {} end
      if not col_c[c] then col_c[c] = {} end

      local child = self.children[i]
      table.insert(row_c[r], child)
      table.insert(col_c[c], child)
    end

    -- fix row heights
    fix_line_param(self, self.row_h, row_c, "height", self.num_rows)
    -- fix column widths
    fix_line_param(self, self.col_w, col_c, "width", self.num_cols)
  end

  function _grid:update_coords()
    ---@type Ui.Object[]
    local row_c = {}
    ---@type Ui.Object[]
    local col_c = {}

    for i, pos in ipairs(self.child_positions) do
      local r, c = table.unpack(pos)
      if not row_c[r] then row_c[r] = {} end
      if not col_c[c] then col_c[c] = {} end

      local child = self.children[i]
      table.insert(row_c[r], child)
      table.insert(col_c[c], child)
    end

    local x = 1
    for i,c in ipairs(row_c) do
      if i > 1 then x = x + self.spacing end

      c.x = x
      x = x + self.col_w[c:index()]
    end

    local y = 1
    for i,c in ipairs(col_c) do
      if i > 1 then y = y + self.spacing end

      c.y = y
      y = y + self.row_h[c:index()]
    end
  end

  function _grid:draw()
    self:update_sizes()
    self:update_coords()
    ui.container.draw(self)

    return self
  end

  ui.grid = _grid
end

return ui