# 08: Launch at login

**What to build:** Locked registers itself to launch at login the first time it runs, so scheduled sessions work without me opening it. Settings has a toggle to turn this off and on.

**Blocked by:** 01

**Status:** ready-for-agent

- [ ] On first launch the app registers as a login item
- [ ] The Settings toggle reflects the real registration state, including changes made in System Settings
- [ ] Turning the toggle off unregisters it and the choice survives relaunch
- [ ] After logging out and back in with the toggle on, Locked is running in the menu bar
