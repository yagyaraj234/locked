# Locked

A personal macOS menu bar app that blocks distracting apps and sites during sessions you define. Spec: `.scratch/locked-v1/spec.md`.

Requires macOS 15+, Xcode, and `xcodegen` (`brew install xcodegen`).

```sh
xcodegen                                             # generate Locked.xcodeproj (git-ignored)
xcodebuild -scheme Locked -derivedDataPath build build   # build
open Locked.xcodeproj                                # then Run in Xcode
xcodebuild -scheme Locked -derivedDataPath build test    # run the policy tests
```

The build is ad-hoc signed, so macOS re-asks for browser Automation access after each rebuild. To stop that, sign in to Xcode with an Apple ID and set a development team on the Locked target.

## How it works

- All blocking decisions live in `Locked/Policy.swift`, which is pure and is the only code under test. Everything else is verified by running the app.
- Apps are hidden, never quit, and covered by a full-screen block screen.
- Sites are caught by reading the front tab's address about once a second. Safari and Chromium browsers (Chrome, Arc, Brave, Edge, Helium, Vivaldi…) are recognised from their app bundle and read through Apple Events; macOS asks for Automation access the first time each is read. Firefox-family browsers (Firefox, Zen, LibreWolf, Floorp…) can't be scripted, so they are read through Accessibility and need that permission for Locked. The Firefox path is untested: none was installed.

- Setup also asks for every permission Locked needs (Automation for each installed Chromium browser and Safari, Accessibility if a Firefox-family browser is installed), and won't finish, so no session is created, until all are allowed.
- On first launch a short setup asks for a goal, what to block and when, and creates the first session from the answers. It can be run again from Settings (Setup Guide…). What you pick there goes into the Every Session list, which is blocked whenever any session is active.

### Block page

Tried on 2026-11-15 by redirecting a tab through Apple Events:

- **Chrome** loads the bundled `block.html`, so Chromium browsers are redirected to that page with the goal in it. Only Chrome and Helium were installed to try; other Chromium browsers use the same code path and are unconfirmed. Firefox-family browsers get `about:blank` typed into the address bar plus the native block screen.
- **Safari** silently ignores a redirect to a `file://` address but accepts `about:blank`, so Safari tabs go to `about:blank` and the native block screen shows the goal.
