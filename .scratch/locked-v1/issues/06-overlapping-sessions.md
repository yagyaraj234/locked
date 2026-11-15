# 06: Overlapping sessions

**What to build:** Two sessions can be active at once, for example a manual "Start now" during a scheduled session. Together they block the union of their lists. Each block shows the goal of the session that caused it; if both block the same target, the one earlier in the saved order wins. The panel lists every active session with its own time remaining.

**Blocked by:** 03

**Status:** ready-for-agent

- [ ] A manual session can be started while a scheduled one is active, and the reverse
- [ ] Apps and sites from both sessions are blocked
- [ ] The block screen and block page show the goal of the session responsible for that target
- [ ] When one session ends, the other keeps blocking its own list
- [ ] The panel shows each active session and its time remaining
- [ ] Policy tests cover: union of lists, goal attribution, the tie-break, and one of two sessions ending
