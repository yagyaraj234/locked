# 05: Permission warnings

**What to build:** When Locked can't read a browser's tabs because the Automation permission is missing or denied, the panel shows a warning row naming that browser, with a button that opens the Automation pane of System Settings. The row goes away once the permission is granted. There is no onboarding flow, and app blocking keeps working regardless.

**Blocked by:** 04

**Status:** ready-for-agent

- [ ] Denying Automation for a browser produces a warning row naming it
- [ ] The row's button opens the Automation pane of System Settings
- [ ] Granting the permission removes the row without relaunching
- [ ] Browsers that are not installed or not running produce no warning
- [ ] App blocking works with every browser permission denied
