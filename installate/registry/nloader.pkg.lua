return {
  name = "Null's GUI Bootloader",

  files = {
    ["/eeprom.min.lua"] = { source = "github", repo = "nullium21/oc-prog", path = "gui-eeprom/eeprom.min.lua" }
  },

  postinstall = function ()
    local eeprom = require("component").eeprom

    local file = io.open("/eeprom.min.lua", "r")
    local data = file:read("*a")
    file:close()

    eeprom.set(data)
    eeprom.setLabel("GUI Bootloader")
  end
}
