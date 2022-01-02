local gpu = require("component").gpu
local net = require("component").internet
local event = require("event")
local fs = require("filesystem")

local szx, szy = gpu.maxResolution()
gpu.setResolution(szx, szy)

gpu.setBackground(0xe1e1e1)
gpu.fill(1,1, szx,szy, ' ')

gpu.setForeground(0x5a5a5a)

local function draw_text_centered(text, y)
  local x = math.floor((szx - #text) / 2)
  gpu.set(x, y, text)
end

local sources = {
  github = function (it) return string.format("https://raw.githubusercontent.com/%s/%s/%s", it.repo, it.branch or "main", it.path) end
}

local installs = {
  ["/eeprom.lua"] = { source = "github", repo = "nullium21/oc-prog", path = "gui-eeprom/eeprom.lua" },
  ["/eeprom.min"] = { source = "github", repo = "nullium21/oc-prog", path = "gui-eeprom/eeprom.min.lua" }
}

local postinstall = {}

-- Files to install:
--
--  - /eeprom.lua (from github: repo=nullium21/oc-progs, path=gui-eeprom/eeprom.lua)
--
-- [ OK ] [ Cancel ]

-- No files will be installed.
-- [ OK ]

-- Installing /eeprom.lua...
-- 100% ##########

local function draw_first_screen(state)
  gpu.setBackground(0xe1e1e1)
  gpu.fill(1,1, szx,szy, ' ')

  local total_hgt = (#installs > 0) and (#installs + 4) or 2

  local y = math.floor((szy-total_hgt) / 2)

  local strings = {}
  for path, inst in pairs(installs) do
    local kv = {}
    for k, v in pairs(inst) do
      if k ~= 'source' then table.insert(kv, k..'='..v) end
    end
    local s = (" - %s (from %s: %s)"):format(path, inst.source, table.concat(kv, ', '))

    table.insert(strings, s)
  end

  draw_text_centered("Files to install:", y)
  y = y + 2

  local max_w = 0
  for i,s in ipairs(strings) do if #s > max_w then max_w = #s end end

  local x = math.floor((szx - max_w) / 2)
  for i,s in ipairs(strings) do
    gpu.set(x, y, s)
    y = y + 1
  end

  y = y + 1
  local buttons = { " [ OK ] ", " [ Cancel ] " }

  x = math.floor((szx - #(table.concat(buttons, "  ")))  / 2)
  for i, btn in ipairs(buttons) do
    if i == state.selected_button then
      gpu.setBackground(0xb4b4b4)
    else
      gpu.setBackground(0xe1e1e1)
    end

    gpu.set(x, y, btn)
    x = x + #btn + 2
  end
end

local function first_screen()
  local state = {
    selected_button = 1
  }

  while true do
    draw_first_screen(state)

    local evt = table.pack(event.pull())

    if evt[1] == "key_down" then
      local _, _, _, code, _ = table.unpack(evt)

      if code == 203 then
        state.selected_button = state.selected_button - 1

        if state.selected_button < 1 then state.selected_button = 2 - state.selected_button end
      elseif code == 205 then
        state.selected_button = state.selected_button + 1

        if state.selected_button > 2 then state.selected_button = state.selected_button - 2 end
      elseif code == 28 then
        return state.selected_button == 1
      end
    end
  end
end

local function download(url, on_progress)
  local h = net.request(url)

  if (h.finishConnect and h.finishConnect()) or not h.finishConnect then
    local resp_code, resp_msg, headers = h.response()

    if resp_code ~= 200 then
      return nil, "response code " .. tostring(resp_code) .. ": " .. resp_msg
    end

    local buf = ""

    local content_size = headers["Content-Length"]
    local part_size = math.huge
    if content_size then
      content_size = tonumber(content_size[1])
      part_size = math.max(math.floor(content_size / 10), 128)
      part_size = math.min(part_size, content_size)
    end

    repeat
      local data, reason = h.read(part_size)
      if not data and reason then return nil, "couldn't read response: " .. reason end
      buf = buf .. (data or "")

      local p = content_size and (#buf / content_size) or 1
      on_progress(p, data, buf)
    until not data

    return buf
  else
    return nil, "couldn't connect"
  end
end

local function download_screen(path, url)
  gpu.setBackground(0xe1e1e1)
  gpu.fill(1,1, szx,szy, ' ')

  local y = math.floor((szy - 3) / 2)

  draw_text_centered("Downloading " .. path .. " (" .. url .. ")...", y)
  y = y + 2

  local pb_width = 15 -- "100% ##########"
  local pb_fmt = "%03d%% %s"
  local pb_x = math.floor((szx-pb_width)/2)

  local function progressbar(progress)
    local num_complete = math.floor(progress * 10)
    gpu.set(pb_x, y, pb_fmt:format(num_complete*10, ("#"):rep(num_complete)))
  end

  progressbar(0)

  local fh = fs.open(path, "w")
  -- fh:seek("set")

  local data, reason = download(url, progressbar)

  if data then
    fh:write(data)

    gpu.setBackground(0xb4b4b4)
    draw_text_centered(" [ OK ] ", y + 2)

    while true do
      local evt = table.pack(event.pull())
      if evt[1] == "key_down" and evt[4] == 28 then
        return true
      end
    end
  else
    return reason
  end
end

-- Installation finished.
--
-- Installed successfully:
-- - /eeprom.min
--
-- Installed with errors:
-- - /eeprom.lua: ...
--
-- [ Exit ]

local function exit_screen(statuses)
  gpu.setBackground(0xe1e1e1)
  gpu.fill(1,1, szx,szy, ' ')

  local ok, not_ok = {}, {}
  for path, status in pairs(statuses) do
    if status == true then table.insert(ok, path)
    else table.insert(not_ok, path) end
  end

  local total_h = 6 + #ok + #not_ok
  local y = (szy - total_h) / 2

  draw_text_centered("Installation finished.", y)
  y = y + 2

  draw_text_centered("Installed successfully (" .. tostring(#ok) .. "/" .. tostring(#ok+#not_ok) .. "):", y)
  for i,path in ipairs(ok) do y = y + 1; draw_text_centered(" - " .. path, y) end
  y = y + 2

  draw_text_centered("Installed with errors (" .. tostring(#not_ok) .. "/" .. tostring(#ok+#not_ok) .. "):", y)
  for i,path in ipairs(not_ok) do
    y = y + 1
    draw_text_centered(" - " .. path .. ": " .. statuses[path], y)
  end
  y = y + 2

  gpu.setBackground(0xb4b4b4)
  draw_text_centered(" [ Exit ] ", y)

  while true do
    local evt = table.pack(event.pull())
    if evt[1] == "key_down" and evt[4] == 28 then
      return true
    end
  end
end

if first_screen() then
  local statuses = {}

  for path, data in pairs(installs) do
    local url = sources[data.source](data)
    statuses[path] = download_screen(path, url)
  end

  exit_screen(statuses)
end
