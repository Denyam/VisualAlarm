# VisualAlarm — Agent Guide

Multiplatform (iOS + macOS) SwiftUI alarm app: scheduled alarms play a sound
and flicker screen brightness between min/max; iPhone additionally blinks the
torch. License: GPLv3. Goal: Mac App Store distributable.

## Hard constraints (never violate)

- Keep App Sandbox enabled on every macOS target (App Store requirement).
- Public APIs only — NO private frameworks (no `CoreDisplay_SetUserBrightness`,
  no `_DS*` DisplayServices symbols, …).
- Screen brightness on macOS exclusively via public IOKit:
  enumerate `IODisplayConnect` services, read/write float parameter
  `kIODisplayBrightnessKey` with `IODisplayGet/SetFloatParameter`.
- A sandboxed app may only install SANDBOXED launchd helpers (macOS 14.2+
  SMAppService rule). All mac executables share the same entitlements set:
  App Sandbox + App Group.
- iOS cannot execute code when a background notification fires. Full effect
  runs only while the app is foreground or after tapping the notification.
  No silent-audio/background-task hacks.

## Architecture (macOS)

- `VisualAlarm.app` — SwiftUI UI; owns registration + alarm store writes.
- `Contents/MacOS/VisualAlarmAgent` — resident scheduler binary
  (`RunAtLoad` + `KeepAlive`), launched by launchd via
  `SMAppService.agent(plistName:)`. Static plist ships inside the app bundle at
  `Contents/Library/LaunchAgents/co.denis.VisualAlarm.agent.plist`.
- `Contents/Library/LoginItems/VisualAlarmRunner.app` — LSUIElement alarm
  window: system-sound loop, brightness flicker, Stop button (rings until
  stopped), single-instance guard.
- IPC: App Group container `co.denis.VisualAlarm.shared` holds `alarms.json`;
  change/fire signaling via Darwin notifications. No launch arguments.

## Conventions

- Timers/scheduling/effects: Swift Concurrency only (`Task.sleep` +
  `ContinuousClock`, sleep chunks ≤ 30 s, cancellable Tasks). Never
  `DispatchSourceTimer` or `Timer` for scheduling or effects.
- Platform splits via `#if os(...)` or synchronized-folder platform filters
  (`VisualAlarm/BrightnessController.swift` is currently iOS-only).
- Restore original brightness/torch state when an alarm stops.
- Testing is interleaved: implement unit → commit → unit tests → run green →
  separate test commit. Larger-scale verification happens at each slice gate.
- Work happens on feature branches off `main`, small imperative commits
  ("Add …", "Fix …"), pushed to origin after every commit. Never touch `main`.

## Build & verify

- Build (macOS):
  `xcodebuild -project VisualAlarm.xcodeproj -scheme VisualAlarm -destination 'platform=macOS' build`
- Build (iOS Simulator):
  `xcodebuild -project VisualAlarm.xcodeproj -scheme VisualAlarm -destination 'generic/platform=iOS Simulator' build`
- Unit tests: `xcodebuild test` with schemes created in PLAN.md step 3
  (concrete simulator picked at test time).

## Gotchas

<!-- Append durable discoveries here (signing quirks, IOKit behavior, …) -->
