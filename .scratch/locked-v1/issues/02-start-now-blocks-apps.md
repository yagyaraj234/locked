# 02: Start now blocks apps

**What to build:** I can create a session in Settings with a name, a goal and a list of apps picked from the Applications folder. From the panel I start it for a chosen duration. While it runs, switching to or launching a blocked app hides that app and shows a full-screen block screen with my goal and a "Back to work" button. The panel shows the session and the time remaining, and the menu bar icon changes. When the time is up, everything opens again. Sessions and the running session survive a relaunch.

This ticket introduces the blocking policy module described in `spec.md` (the single test seam), covering manual runs and app targets.

**Blocked by:** 01

**Status:** ready-for-agent

- [ ] Settings can create, edit and delete sessions with a name, a goal and apps chosen with the standard open panel
- [ ] Apps are stored by bundle ID
- [ ] The panel's "Start now" lets me pick a session and a duration
- [ ] Bringing a blocked app to the front hides it and shows the block screen with that session's goal
- [ ] An app already open when the session starts is blocked the next time it comes forward
- [ ] No app is ever terminated; Locked, Finder and System Settings are never blocked
- [ ] "Back to work" dismisses the block screen
- [ ] The panel shows the active session, time remaining and blocked apps; the menu bar icon differs while a session is active
- [ ] The session ends on time and the apps become usable again
- [ ] Sessions and an in-progress manual run persist across relaunch
- [ ] Policy tests cover: a manual run before and after its end time, blocked and unblocked bundle IDs, and no active session
