# Locked

A personal macOS menu bar app that blocks distracting apps and sites during sessions you define. Spec: `.scratch/locked-v1/spec.md`.

Requires macOS 14+, Xcode, and `xcodegen` (`brew install xcodegen`).

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
- Sites are caught by reading the front tab's address about once a second through Apple Events. macOS asks for Automation access the first time each browser is read.

### Block page

Tried on 2026-11-15 by redirecting a tab through Apple Events:

- **Chrome** loads the bundled `block.html`, so Chromium browsers (Chrome, Arc, Brave, Edge) are redirected to that page with the goal in it. Only Chrome was installed to try; the other three use the same code path and are unconfirmed.
- **Safari** silently ignores a redirect to a `file://` address but accepts `about:blank`, so Safari tabs go to `about:blank` and the native block screen shows the goal.
