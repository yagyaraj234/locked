# 03: Scheduled sessions

**What to build:** In Settings I can give a session days of the week and start and end times. The session then starts and stops on its own. An end time earlier than the start time means it crosses midnight and belongs to the day it starts on. If the app relaunches or the Mac wakes in the middle of a window, the session is active straight away. A session with no schedule stays manual-only.

**Blocked by:** 02

**Status:** ready-for-agent

- [ ] Settings can set, change and clear a session's weekdays, start time and end time
- [ ] A scheduled session becomes active at its start time and inactive at its end time without any interaction
- [ ] A window crossing midnight stays active into the next morning, and only on nights that begin on a selected weekday
- [ ] After a relaunch or wake inside a window, the session is active and blocking
- [ ] The panel shows time remaining for a scheduled session
- [ ] Policy tests cover: weekday selection, start and end boundaries, midnight crossing on both sides of midnight, and a session with no schedule
