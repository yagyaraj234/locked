# Locked v1

**Status:** ready-for-agent

## Problem Statement

I lose hours on my Mac to distracting apps and websites, during work and late at night. Willpower alone doesn't hold: the app or tab is open before I've decided anything. Existing blockers such as Sheltered do the job but are paid, need an account, and carry features I don't need. I want a small tool of my own that closes the distractions during the hours I choose and reminds me why.

## Solution

Locked is a personal macOS menu bar app. I define named sessions, each with a goal, a list of apps, a list of sites, and optionally a weekly schedule. While a session is active, opening a blocked app hides it behind a full-screen block screen showing my goal, and opening a blocked site in Safari or a Chromium browser redirects the tab to a block page. Sessions start and stop on schedule, or I start one by hand for a chosen duration. Ending a session early costs a 60-second wait. There are no accounts, no payments, and nothing leaves the Mac.

## User Stories

### Sessions

1. As a user, I want to create a named session, so that I can keep separate rules for work and for winding down.
2. As a user, I want to give each session its own goal, so that the block screen reminds me why that session exists.
3. As a user, I want to add apps to a session by picking them from my Applications folder, so that I don't have to type bundle identifiers.
4. As a user, I want to add sites to a session by typing a domain, so that the whole site is blocked, including subdomains.
5. As a user, I want to add a site with a path, such as a video site's short-form feed, so that only that part is blocked and the rest stays usable.
6. As a user, I want to edit and delete sessions, so that my rules keep up with my habits.
7. As a user, I want my sessions to persist across relaunches and restarts, so that I set them up once.

### Starting and scheduling

8. As a user, I want to start a session immediately for a chosen duration, so that I can focus on demand.
9. As a user, I want to give a session days of the week and start and end times, so that it runs without me remembering to start it.
10. As a user, I want a session to cross midnight, so that a late-night session can run from evening into the next morning.
11. As a user, I want scheduled sessions to start and stop on their own, so that the blocks open again on time.
12. As a user, I want a scheduled session to be correctly active after the app relaunches or the Mac wakes mid-window, so that sleep or a restart isn't a loophole.
13. As a user, I want a session with no schedule to exist only for manual starts, so that not every session has to be recurring.

### Blocking apps

14. As a user, I want a blocked app hidden the moment I switch to or launch it, so that I never get to use it during a session.
15. As a user, I want a full-screen block screen showing my goal when that happens, so that I'm reminded what I meant to be doing.
16. As a user, I want a "Back to work" button that dismisses the block screen, so that I can carry on immediately.
17. As a user, I want blocked apps never to be force-quit, so that I can't lose unsaved work.
18. As a user, I want an app that was already open when a session started to be blocked when I next bring it forward, so that leaving it open isn't a loophole.

### Blocking sites

19. As a user, I want a blocked site's tab redirected to a block page showing my goal, so that the site is gone, not just covered.
20. As a user, I want site blocking to work in Safari and in Chromium browsers (Chrome, Arc, Brave, Edge), so that switching browser isn't a loophole among the ones I use.
21. As a user, I want a blocked site caught whether I typed it, followed a link, or switched to an existing tab, so that every route to it is closed.
22. As a user, I want sites that are not on the list left alone, so that the blocker never gets in the way of work.

### Overlap

23. As a user, I want two active sessions to block the union of their lists, so that starting a manual session never weakens a scheduled one.
24. As a user, I want each block to show the goal of the session that caused it, so that the reminder is the relevant one.
25. As a user, I want ending one session to leave the other running, so that sessions stay independent.

### Ending early and friction

26. As a user, I want to be able to end a session early, so that a real need isn't blocked by my own tool.
27. As a user, I want ending early to cost a 60-second countdown with the window in front, so that I only do it deliberately.
28. As a user, I want the countdown to reset if I leave the window, so that I can't start it and go elsewhere.
29. As a user, I want no Quit option while a session is active, so that quitting isn't the easy way out.
30. As a user, I want an active session's block list locked against edits, so that I can't quietly remove the app I'm craving.
31. As a user, I want the same early-end rule for manual and scheduled sessions, so that the rule is easy to hold in my head.

### Menu bar and settings

32. As a user, I want the app to live in the menu bar with no Dock icon, so that it stays out of the way.
33. As a user, I want the menu bar icon to change while a session is active, so that I can tell at a glance.
34. As a user, I want the panel to show the active sessions, the time remaining, and what is blocked, so that I know my current state.
35. As a user, I want "Start now" and "End early" in the panel, so that the common actions are one click away.
36. As a user, I want a separate Settings window for creating and editing sessions, so that the panel stays small.
37. As a user, I want the app to launch at login by default, so that scheduled sessions run without me opening it.
38. As a user, I want a toggle for launch at login, so that I can turn it off.

### Permissions

39. As a user, I want app blocking to work without granting any permission, so that the app is useful from first launch.
40. As a user, I want a warning row in the panel when a browser's Automation permission is missing, so that I know site blocking isn't working there.
41. As a user, I want that warning to carry a button to the right System Settings pane, so that fixing it takes one click.
42. As a user, I want no onboarding flow, so that I'm only asked for a permission when it is needed.

## Implementation Decisions

- **Platform and stack:** macOS 14+, Swift and SwiftUI, a menu bar app built on `MenuBarExtra`, a single app target plus a test target, no third-party dependencies.
- **Project:** the Xcode project is generated from a `project.yml` with `xcodegen`; the generated project is git-ignored. Bundle ID `com.yagyaraj.locked`. The app is an agent app with no Dock icon.
- **Sandbox and distribution:** unsandboxed, run locally from Xcode. No App Store, no notarization.
- **Signing:** ad-hoc to begin with. macOS ties the Automation permission to the signature, so ad-hoc builds re-prompt for browser access after each rebuild. The owner signs in to Xcode with a free Apple ID to get a personal development certificate; the project then switches to it. This is a manual step for the owner, not agent work.
- **Session model:** a session has an identity, a name, a goal, a list of app bundle IDs, a list of site rules, and an optional schedule (a set of weekdays plus start and end times of day). An end time earlier than the start time means the window crosses midnight and belongs to the weekday it starts on. A manual run is a session identity plus an end time.
- **Persistence:** sessions and active manual runs are stored locally as JSON (in `UserDefaults` or a file in Application Support). Manual runs persist so a relaunch doesn't end them.
- **Blocking policy module:** one pure module holds all the decision logic. Given the saved sessions, the manual runs, the current time and a target (an app bundle ID or a URL), it answers "allowed" or "blocked by this session, with this goal". It also answers which sessions are active at a given time. It has no dependency on AppKit, timers or the clock; time is passed in.
- **Site rules:** a rule is a domain with an optional path prefix. A URL matches if its host equals the domain or is a subdomain of it, and its path starts with the prefix if one is given. Matching ignores scheme, port, query, a leading `www.`, and letter case in the host. There is no allowlist mode.
- **Overlap:** active sessions block the union of their lists. When several active sessions block the same target, the goal shown comes from one of them chosen deterministically (the earliest in the saved order).
- **App blocking:** observe application activation and launch through `NSWorkspace`. When the frontmost app is blocked, hide it and show the block screen. Apps are never terminated. Locked itself, Finder and System Settings are never blocked, whatever the list says.
- **Site blocking:** while a supported browser is frontmost and a session with site rules is active, read the active tab's URL through Apple Events roughly once a second and, on a match, set the tab's URL to the block page. Supported browsers: Safari, Chrome, Arc, Brave, Edge. Firefox is unsupported.
- **Block page (open risk):** first choice is a bundled local page showing the goal. If browsers refuse an Apple Events redirect to a local page, fall back to redirecting to `about:blank` and showing the native block screen used for apps. The site-blocking ticket settles this by trying it.
- **Block screen:** a full-screen window above other apps showing the goal and a "Back to work" button that dismisses it.
- **Ending early:** a 60-second countdown in a window that must stay frontmost; losing focus resets it. Applies equally to manual and scheduled sessions. Ending a scheduled session early suppresses it until its current window ends; the next window runs as normal.
- **Session lock:** while any session is active the Quit command is absent, and that session's block list, goal and schedule cannot be edited or deleted. Inactive sessions remain editable.
- **Interface:** the panel shows active sessions, time remaining, blocked items, "Start now" (pick a session and a duration), "End early", permission warnings, and a link to Settings. Settings is a separate window for session CRUD and the launch-at-login toggle. Apps are picked with the standard open panel rooted at the Applications folder.
- **Launch at login:** registered through `SMAppService`, on by default, with a toggle.
- **Permissions:** no onboarding. Each browser prompts for Automation the first time it is read. A denied or missing permission produces a warning row naming the browser, with a button that opens the Automation pane of System Settings.
- **Notifications:** none. The menu bar icon is the only signal that a session is active.

## Testing Decisions

- A good test exercises external behaviour through a module's public interface and would survive a rewrite of its internals. Tests pass time in explicitly; none reads the real clock.
- There is one test seam: the blocking policy module. Tests there cover:
  - schedule activity: weekdays, start and end boundaries, windows crossing midnight, sessions with no schedule, manual runs before and after their end time;
  - site matching: exact domain, subdomains, lookalike domains that must not match, path prefixes, `www.` and case handling;
  - overlap: union of lists across active sessions, and which session's goal is reported.
- Everything outside that seam (`NSWorkspace` observation, Apple Events, windows, launch at login) is verified by hand, by running the app.
- There is no prior art; the repository is empty. The tests added with the first policy logic set the pattern.

## Out of Scope

- Daily time limits and open-count limits.
- Difficulty levels and weekly emergency passes.
- Insights, scores and streaks.
- Soundscapes.
- Firefox, and feed-only blocking beyond what a path prefix gives.
- Allowlist mode.
- A privileged helper or daemon that resists force-quitting from Activity Monitor.
- Notifications.
- Accounts, payments, licensing, notarization, App Store distribution.
- iPhone.

## Further Notes

- Inspired by Sheltered (sheltered.app). Locked uses its own name and look and none of Sheltered's branding.
- Friction is deliberate but light: anyone can still kill the process. A helper is worth adding only if that turns out to be a real habit.
- Tickets are in the `issues` folder beside this spec, numbered in dependency order.
