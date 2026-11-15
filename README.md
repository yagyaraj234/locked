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
