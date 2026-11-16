# Locked

A personal project for blocking distracting apps and sites during sessions you define. One repo, one folder per platform.

| Path | What it is |
| --- | --- |
| `apps/macos/` | Menu bar app for macOS (Swift). See its [README](apps/macos/README.md) to build and run. |
| `apps/web/` | Marketing website. Placeholder for now. |
| `design/` | Shared design sources, such as the app icon SVG and the script that renders it for each platform. |
| `.scratch/locked-v1/` | Product spec and issue list. |

Planned: `apps/ios/` and `apps/android/`. Each app keeps its own build setup inside its folder. Shared code (for example, the blocking rules) can go in a `packages/` folder once a second platform needs it.
