## Installate - a simple installer for all your apps

This is a WIP GUI-based installer for apps/libraries that only requires the `event` and `filesystem` libraries, along with `GPU` and `Internet Card` components.

### How to install:
1. Download the `installate.lua` file and put it into `/bin`.
2. Profit!

### How to use:
1. Get a manifest file (`NAME.pkg.lua`). One for the GUI bootloader can be downloaded [here](https://github.com/nullium21/oc-prog/blob/main/installate/eeprom.pkg.lua).
2. Run Installate with the manifest as a parameter: `installate YOURMANIFEST.pkg.lua`.
3. Follow instructions on screen.

### Planned features:
- [x] a GUI for installing the stuff,
- [x] fetching files from internet,
- [x] loading app definitions from files,
- [ ] loading app definitions from internet
