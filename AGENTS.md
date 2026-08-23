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
- `Contents/Library/LoginItems/VisualAlarmAgent.app` — resident scheduler
  agent (`RunAtLoad` + `KeepAlive`), launched by launchd via
  `SMAppService.agent(plistName:)`. Static plist ships inside the app bundle at
  `Contents/Library/LaunchAgents/co.denis.VisualAlarm.agent.plist`; its
  `BundleProgram` path points into the nested agent bundle (sandboxed
  executables cannot be bare binaries — see Gotchas).
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

### Spike 2026-08-22: IOKit brightness under App Sandbox (`spike/`, rerun via `spike/run_spike.sh`)
- `IODisplayGet/SetFloatParameter` with `kIODisplayBrightnessKey`
  (= `"brightness"`) WORKS inside the App Sandbox — verified with ad-hoc
  signing: container created, all calls return 0, min→max→restore observed.
- **Sandboxed executables MUST be `.app` bundles**: a bare Mach-O with the
  App Sandbox entitlement dies with SIGILL during `libsecinit` ("Info.plist …
  no value for kCFBundleIdentifierKey"). This is why the agent ships as a
  bundle, not a plain binary.
- Swift's IOKit overlay does not export `IODisplay*FloatParameter`; expose
  them via an ObjC bridging header (`#import <IOKit/graphics/IOGraphicsLib.h>`)
  or `dlsym`.
- Don't detect sandboxing by probing `$HOME` writes (unreliable on this OS
  build); check for `~/Library/Containers/<bundle-id>` instead.

### Runner bootstrap: delegate must be installed before `app.run()` (step 4)
- `NSApplication.delegate` set inside `Task { @MainActor }` executes only
  AFTER `app.run()` has already delivered `applicationDidFinishLaunching` —
  the app then runs "headless" (no window/sound/effects) while termination
  callbacks still work. Top-level main.swift runs on the main thread, so use
  `MainActor.assumeIsolated { ... }` for synchronous MainActor setup.
- The single-instance guard exits silently by design; it now prints a line so
  a stray background instance doesn't masquerade as "app does nothing".
- Stop UI must be a plain `NSWindow`, not an `NSPanel`: panels default to
  `hidesOnDeactivate = true` and never become key while an accessory app is
  inactive, so the window stays invisible even after orderFront. Activate via
  `NSApp.activate(ignoringOtherApps:)` only AFTER the run loop starts
  (`DispatchQueue.main.async`) — earlier requests are dropped.

### Embedding mac helpers in a multiplatform target (step 3 findings)
- A single multiplatform target cannot use CopyFiles phases for macOS-only
  helpers: on iOS builds `ValidateEmbeddedBinary` fails ("target is built for
  iOS but contains embedded content built for macOS") even if the phase
  destination points outside the bundle, and `platformFilters` on PBXBuildFile
  is not honored for copy-phase members.
- Working setup: Run Script phase that early-exits unless
  `$PLATFORM_NAME == macosx`, with declared input/output paths; requires
  `ENABLE_USER_SCRIPT_SANDBOXING = NO` on the app target (declared output
  trees are not writable recursively under the script sandbox).
- The embed script must `rm -rf` destination helper bundles before copying:
  BSD `cp -R` merges INTO an existing directory, silently leaving stale
  binaries embedded. Phase also sets `alwaysOutOfDate = 1` so incremental
  builds can never skip re-embedding.
