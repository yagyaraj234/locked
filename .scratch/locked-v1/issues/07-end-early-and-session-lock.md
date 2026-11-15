# 07: End early and session lock

**What to build:** The panel's "End early" opens a window with a 60-second countdown. The window has to stay in front; leaving it resets the countdown. When it finishes, that session ends. While any session is active there is no Quit command, and an active session can't be edited or deleted. The rule is the same for manual and scheduled sessions.

**Blocked by:** 02

**Status:** ready-for-agent

- [ ] "End early" on an active session starts a 60-second countdown
- [ ] Switching away from the countdown window resets it
- [ ] Completing the countdown ends that session and unblocks its list
- [ ] Ending a scheduled session early keeps it off until its current window ends, and the next window runs normally
- [ ] The Quit command is absent while any session is active and present otherwise
- [ ] An active session's name, goal, lists and schedule can't be edited or deleted; inactive sessions can
- [ ] Policy tests cover a scheduled session suppressed for the rest of its window, if ticket 03 has landed
