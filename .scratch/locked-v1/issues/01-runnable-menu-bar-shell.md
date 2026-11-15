# 01: Runnable menu bar shell

**What to build:** Locked builds and runs as a menu bar app. Clicking its icon opens a panel; the panel opens an empty Settings window. There is no Dock icon. The repository is under git and the Xcode project is generated from a `project.yml` with `xcodegen`. See `spec.md` for the platform, project and signing decisions.

**Blocked by:** None (can start immediately)

**Status:** ready-for-agent

- [ ] The folder is a git repository, and the generated Xcode project is git-ignored
- [ ] Running `xcodegen` produces a project that builds for macOS 14+ with no third-party dependencies
- [ ] The app is unsandboxed, ad-hoc signed, with bundle ID `com.yagyaraj.locked`
- [ ] Launching the app shows a menu bar icon and no Dock icon
- [ ] The panel has a control that opens a Settings window and a Quit command
- [ ] A test target exists and one placeholder test passes from the command line
- [ ] A short README says how to generate, build, run and test
