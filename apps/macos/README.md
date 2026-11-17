# Locked for macOS

A personal macOS menu bar app that blocks distracting apps and sites during sessions you define. Spec: `../../.scratch/locked-v1/spec.md`.

Requires macOS 15+, Xcode, and `xcodegen` (`brew install xcodegen`).

```sh
cd apps/macos
xcodegen                                             # generate Locked.xcodeproj (git-ignored)
xcodebuild -scheme Locked -derivedDataPath build build   # build
open Locked.xcodeproj                                # then Run in Xcode
xcodebuild -scheme Locked -derivedDataPath build test    # run the policy tests
```

The build is ad-hoc signed, so macOS re-asks for Accessibility access after each rebuild. To stop that, sign in to Xcode with an Apple ID and set a development team on the Locked target.

## How it works

- All blocking decisions live in `Locked/Policy.swift`, which is pure and is the only code under test. Everything else is verified by running the app.
- Apps are hidden, never quit, and covered by a full-screen block screen.
- Sites are caught by reading the front tab's address about once a second. Safari, Chromium browsers (Chrome, Arc, Brave, Edge, Helium, Vivaldi…) and Firefox-family browsers (Firefox, Zen, LibreWolf, Floorp…) are recognised from their app bundle and all read through Accessibility, so Locked needs that one permission and nothing per browser. The Firefox path is untested: none was installed.
- Setup asks for that Accessibility permission, and won't finish until it is allowed if the list has sites. With no sites it isn't needed.
- On first launch a short setup asks for a goal, what to block and when, and creates the first session from the answers. It can be run again from Settings (Setup Guide…). What you pick there goes into the Every Session list, which is blocked whenever any session is active.

### Block page

Tried on 2026-11-16 by typing an address into the tab's address bar through Accessibility:

- **Chrome** loads the bundled `block.html`, so Chromium browsers are redirected to that page with the goal in it. Its address bar ignores an Accessibility confirm, so Locked presses Return in it instead. Only Chrome was tried; other Chromium browsers use the same code path and are unconfirmed. Firefox-family browsers get `about:blank` plus the native block screen.
- **Safari** did not load a `file://` address this way but accepts `about:blank`, so Safari tabs go to `about:blank` and the native block screen shows the goal.
