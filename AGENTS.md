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
- `Contents/XPCServices/VisualAlarmAgentXPC.xpc` — resident scheduler, kept
  alive by launchd (`RunAtLoad` + `KeepAlive`) via
  `SMAppService.agent(plistName:)`. Static plist ships inside the app bundle at
  `Contents/Library/LaunchAgents/co.denis.VisualAlarm.agent.plist`; its
  `BundleProgram` path points into the nested `.xpc` bundle (sandboxed
  executables cannot be bare binaries — see Gotchas). Runs independently of the
  main app so alarms still fire while the app is closed.
- `Contents/XPCServices/VisualAlarmRunnerXPC.xpc` — LSUIElement alarm window:
  system-sound loop, brightness flicker, Stop button (rings until stopped).
  Started on demand over XPC and torn down when its last connection closes.
- IPC: typed `@objc` protocols in `VisualAlarm/XPC/VisualAlarmXPC.swift`,
  carried by `NSXPCConnection`. Alarms cross the boundary as JSON-encoded
  `Data` (`XPCAlarm`) because Swift structs cannot be `@objc` parameters.
  Change signaling between app and agent remains Darwin notifications. No launch
  arguments.

## Conventions

- Timers/scheduling/effects: Swift Concurrency only (sleep chunks ≤ 30 s,
  cancellable Tasks, `Task.sleep(seconds:)` through the injected sleeper seam
  in `FlickerEffectController` / `AlarmScheduler.step(sleep:)`). NEVER
  `Duration`/`Clock`/`ContinuousClock`/`Task.sleep(for:)` — they require
  macOS 13+ / iOS 16+, above the macOS 10.15 / iOS 15.5 deployment floors
  (use plain `TimeInterval` seconds instead). Never `DispatchSourceTimer` or
  `Timer` for scheduling or effects.
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
- Unit tests: `xcodebuild test -project VisualAlarm.xcodeproj -scheme
  VisualAlarmTests -destination '<dest>'` — `-scheme VisualAlarm` has NO test
  action configured. Destinations: `platform=macOS`, or
  `platform=iOS Simulator,id=<uuid>` (concrete device; generic destinations
  cannot run tests).
- Gate policy: at every step gate run the FULL matrix — macOS destination,
  iOS 15.5 simulator (iPhone 13), iOS 26.3 simulator. macOS 10.15 itself is
  compile-time verification ONLY (runtime not obtainable — documented gap).

## Gotchas

<!-- Append durable discoveries here (signing quirks, IOKit behavior, …) -->

### Signing: ad-hoc + App Sandbox aborts at launch (verified 2026-10-13)
- `codesign --sign -` (ad-hoc, i.e. Xcode Team "None") **plus**
  `com.apple.security.app-sandbox` makes the process die with **SIGABRT before
  `main`**. Reproduced with never-before-seen bundle IDs, from `/tmp` and from
  the repo, on macOS 15.8.1 / Xcode 16.4. The abort is in process init, so no
  `print`/stderr output appears. Measured via `spike/run_appgroup_spike.sh`.
- Ad-hoc signing WITHOUT the sandbox entitlement runs fine — the entitlement,
  not ad-hoc signing per se, is the trigger. Adding
  `com.apple.security.application-groups` changes nothing.
- This **supersedes** the older spike note below claiming the sandboxed spike
  "WORKS with ad-hoc signing"; that result no longer reproduces on this host.
- `security find-identity -v -p codesigning` currently reports **0 valid
  identities**, so Team "None" is the only thing Xcode can sign with here.
- Consequence: the sandboxed build in this repo is expected to **fail to
  launch** until a real signing identity is restored. Verified only by
  `swiftc -typecheck`; `xcodebuild` SIGILLs on this host even on an untouched
  checkout (see below), so no compiled/launch verification was possible.
- XPC services do **not** substitute for App Groups: each sandboxed process
  gets a container keyed by its own bundle ID, so an embedded `.xpc` cannot see
  the app's `alarms.json`. XPC provides messaging, not shared storage.

### xcodebuild is unusable on this host (2026-10-13)
- `xcodebuild ... build` exits **132 (SIGILL)** after printing only the
  invocation line, on an **unmodified** `git worktree` of `HEAD`. Not caused by
  project changes. `swiftc`/`swift-frontend` work normally, so use
  `swiftc -typecheck -sdk $(xcrun --show-sdk-path --sdk macosx) -target
  x86_64-apple-macos10.15 <files>` to verify compilation until this is fixed.

### Old-OS floor: macOS 10.15 / iOS 15.5 (feature/old-os-targets)
- **Known gap**: macOS 10.15 runtime is unobtainable; the mac floor is
  compile-verified only. Runtime coverage = iOS 15.5 + iOS 26.3 + host macOS.
- Swift API floors hit while lowering targets: `Image(systemName:)` and
  `ToolbarItemPlacement` are macOS 11+ (see `VASwiftUI.swift` shims:
  `VASymbolImage`, `vaToolbarItem`, `vaNavigationTitle`, `vaSafeAreaInset`,
  `VAStateObject`, …); `overlay(alignment:content:)` is macOS 12+ (use
  `overlay(_:alignment:)`); `navigationBarTitle` and `StackNavigationViewStyle`
  are iOS-only; `safeAreaInset` takes `VerticalEdge` on BOTH platforms.
- Swift Testing cannot attach `@Test` to `@available`-gated suites/functions —
  use in-body `guard #available(macOS 13.0, *) else { return }`.
- Default-argument expressions are always `nonisolated` — a `@MainActor`
  type's default args must not call isolated methods (use a convenience
  `init()` instead of default params).
- Login-item registration has two backends behind `AgentRegistering`:
  `SMAppServiceRegistrar` (macOS 13+, async status) and `LoginItemRegistrar`
  (`SMLoginItemSetEnabled`, pre-13). The legacy backend gives no status
  feedback, so registration intent is persisted in UserDefaults.
- `AlarmEffectCoordinatorTests/rapidStartStopDoesNotRace` failed by sleeping
  a fixed interval after `stop()`: the cancelled flicker task may not have
  STARTED yet, so the read caught `onPhase`'s 1.0 before `restore()`. Sleeps
  cannot order task completion — await `coordinator.currentEffectTask?.value`
  (the task is only nilled by a MainActor cleanup task, so it is still set
  synchronously right after `stop()`).

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

### App Group naming (step 6 + device-build fix)
- NOTE: as of the XPC refactor the `application-groups` entitlement is REMOVED
  from `Support/VisualAlarm.entitlements`, so none of the below currently
  applies. Retained for reference in case the entitlement comes back (it is
  the only sandbox-sanctioned way to share `alarms.json` across processes).
- A BARE (non-team-prefixed) App Group ID + no provisioning profile makes
  macOS 15+ prompt "access data from other apps" on EVERY launch, and the
  invisible prompt hangs xcodebuild test hosts ("test runner hung before
  establishing connection"). Fix: prefix group with Team ID.
- Team-prefix alone is NOT enough for real-device iOS builds: provisioning
  requires the identifier to BEGIN WITH `group.`. Final working format:
  `group.<TEAMID>.<reverse-dns>` → `group.ETFKU52LQ6.co.denis.VisualAlarm.shared`.
  The same string works on macOS (silent provisioning for same-team apps)
  and iOS device/simulator; keep it for any new groups.
- Test targets must carry the app's `DEVELOPMENT_TEAM` and matching
  deployment targets, or device test runs fail to install.
- Renaming the group orphans the previous container (`~/Library/Group
  Containers/<old-id>`) — alarms.json does not migrate automatically.
- `AlarmStore` posts `.alarmsDidChange` on every successful persist; anything
  mutating the store elsewhere must rely on the store methods (or post
  manually) or resident agents go stale.

### Embedding mac helpers in a multiplatform target (step 3 findings)
- SUPERSEDED by the XPC refactor: the app no longer embeds separate `.app`
  helpers. It now embeds two `.xpc` bundles via a `CopyFiles` phase
  ("Embed XPC Services", `dst_subfolder_spec = plug_ins` →
  `Contents/XPCServices`), which Xcode filters per-platform correctly, plus
  "Embed Agent Plist" (`absolute_path` → `Contents/Library/LaunchAgents`).
  The old Run Script phase ("Embed Helpers (macOS only)") and its `VA_HELPER_DST`
  / `VA_PLIST_DST` settings were deleted. Retained for reference:
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
- `NSXPCListener.delegate` is a WEAK reference: the delegate must be held in a
  strong top-level `let`, or it deallocates immediately and every incoming
  connection is rejected.

### iOS notification scheduling + effects (step 7)
- `@Sendable` closures cannot mutate captured protocol existentials in Swift 5:
  a capture-list binding `[brightness]` of `any ScreenBrightnessControlling`
  creates an immutable local, and even `[self]` is immutable in `@Sendable`
  context on `@MainActor` classes. Workaround: wrap mutable state in a simple
  `final class` box (`BrightnessBox`) and capture the box reference.
- `UNUserNotificationCenter` has no async `getPendingNotificationRequests`
  wrapper — use `withCheckedContinuation` around the completion-handler
  version. The `add(_:)` method collides with an identically-named extension
  method; rename the protocol wrapper to `schedule(_:)`.
- `UINotificationFeedbackGenerator.FeedbackType` has `.success`, `.warning`,
  `.error` — NOT `.alert`.
- iOS-only test files that reference mac-only types (e.g.
  `WorkspaceRunnerLauncher`) MUST be wrapped in `#if os(macOS)` to compile on
  the iOS simulator test host.
- Test files referencing `Alarm` with non-default `id` must place the `id:`
  argument before `hour:` — Swift enforces parameter order even with labeled
  defaults.
