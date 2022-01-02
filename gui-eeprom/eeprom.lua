local cproxy, clist = component.proxy, component.list

local gpu = cproxy(clist("gpu")())
local scr = cproxy(clist("screen")())

-- cinvk(gpu, "bind", scr)
gpu.bind(scr)

local szx, szy = gpu.maxResolution()
gpu.setResolution(szx, szy)

gpu.setBackground(0xe1e1e1) -- 0xe1e1e1
gpu.fill(1,1, szx,szy, ' ')

-- backwards compatibility, may remove later
local eep = cproxy(clist("eeprom")())
computer.getBootAddress = function()
  return eep.getData()
end
computer.setBootAddress = function(address)
  return eep.setData(address)
end

local function try_load_cfg(fsa)
  local fs = cproxy(fsa)
  local h, reason = fs.open("/boot.cfg")
  if not h then return nil, reason end

  local buf = ""
  repeat
    local data, reason = fs.read(h, math.huge)
    if not data and reason then return nil, reason end
    buf = buf .. (data or "")
  until not data

  local cfg = {}
  for k,v in string.gmatch(buf, "(%w+)=(.-)[\r\n]+") do
    cfg[k]=v
  end
  return cfg
end

local function try_boot_from(fsa, file)
  local fs = cproxy(fsa)
  local h, reason = fs.open("/" .. file)
  if not h then return nil, reason end

  local buf = ""
  repeat
    local data, reason = fs.read(h, math.huge)
    if not data and reason then return nil, reason end
    buf = buf .. (data or "")
  until not data

  fs.close(h)
  return load(buf, "=" .. file)
end

local blocs = {}
local msgs = {}
local cfgs = {}
for fsaddr in clist("filesystem") do
  local cfg, reason = try_load_cfg(fsaddr)
  if not cfg then
    table.insert(msgs, "warn: couldn't load boot.cfg from " .. tostring(fsaddr) .. ": " .. tostring(reason))
  else
    if type(cfg.boot) == 'string' then
      table.insert(blocs, { fsaddr, cfg.boot, cfg.name })
      table.insert(cfgs, cfg)
    else
      table.insert(msgs, "warn: couldn't find boot entry in {" .. fsaddr .. "}/boot.cfg")
    end
  end
end

gpu.setForeground(0x5a5a5a) -- 0x5a5a5a

for i,msg in ipairs(msgs) do
  gpu.set(1, i, msg)
end

if #blocs == 0 then
  local msg = "error: couldn't find a boot device. "
  gpu.set((szx-#msg)/2, szy/2, msg)
  while true do end
else
  local sel = 1

  local function draw_boot_locations()
    local y = szy/2 -- - 1
    local msg = "select a boot device: "

    local max_width = #msg

    for i,loc in ipairs(blocs) do
      local drive, file, name = table.unpack(loc)
      local s = ("  %-" .. max_width .. "s"):format(name or (drive .. "/" .. file))
      if #s > #msg then max_width = #s end

      if i == sel then
        gpu.setBackground(0xb4b4b4)
      else
        gpu.setBackground(0xe1e1e1)
      end
      gpu.set((szx-max_width)/2, y, s)
      y = y + 1
    end

    gpu.setBackground(0xe1e1e1)
    gpu.set((szx-max_width)/2, szy/2-1, msg)
  end

  draw_boot_locations()

  while true do
    local pull_ret = table.pack(computer.pullSignal())
    local evt_name = pull_ret[1]

    if evt_name == "key_down" then
      local code = pull_ret[4]

      if code == 200 then -- up
        sel = sel - 1

        if sel < 1 then sel = #blocs - sel end

        draw_boot_locations()
      elseif code == 208 then -- down
        sel = sel + 1

        if sel > #blocs then sel = sel - #blocs end

        draw_boot_locations()
      elseif code == 28 then
        local loc = blocs[sel]
        local from = loc[3] or ("from " .. loc[1])
        local init, reason = try_boot_from(table.unpack(loc))
        if not init then
          error("couldn't boot " .. from .. ": " .. (reason and tostring(reason) or "reason unknown"))
        else
          init(cfgs[sel])
        end
      end
    end
  end
end
