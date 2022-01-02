## GUI EEPROM loader

This is an alternative bootloader for OC's computers, where you can even select where to boot from in a GUI!

### How to install:
1. Flash the `eeprom.lua` or `eeprom.min.lua` to a EEPROM in OpenComputers.
2. Create a `boot.cfg` on your OS drive. For OpenOS it should look like this:
   ```
   file=init.lua
   name=OpenOS
   ```
3. Put the EEPROM into your computer.
4. Start the computer...
5. PROFIT!

### How it works:
The most important pieces of code are the [`try_load_cfg`](https://github.com/nullium21/oc-prog/blob/main/gui-eeprom/eeprom.lua#L24-L41) and [`try_boot_from`](https://github.com/nullium21/oc-prog/blob/main/gui-eeprom/eeprom.lua#L43-L57) functions. The first one loads the `boot.cfg` from a drive, and the second one boots once you've selected the OS.

To find all the boot entries, the script [runs through all the available `filesystem` components](https://github.com/nullium21/oc-prog/blob/main/gui-eeprom/eeprom.lua#L62-L74) and tries to load the file from there.

Then, once all of the GUI is displayed using [`draw_boot_locations`](https://github.com/nullium21/oc-prog/blob/main/gui-eeprom/eeprom.lua#L89-L111) we wait for events, specifically `key_down`. If [the key code is `200` (arrow up)](https://github.com/nullium21/oc-prog/blob/main/gui-eeprom/eeprom.lua#L122), we move the selection up one entry, if it's `208` (arrow down) - we move it down.

But if the code is `28`, which corresponds for Enter, we boot the selected OS and pass the `boot.cfg` contents into it.
