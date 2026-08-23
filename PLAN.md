# PLAN — feature/scheduled-alarms

Working agreement: unit cycle = implement → commit → unit tests → run green →
separate test commit. Slice gates = larger-scale verification before advancing.
Push to origin after every commit. When everything is checked off: archive this
file to `docs/archive/`, remove `"instructions": ["PLAN.md"]` from
`opencode.json`, and promote durable discoveries into `AGENTS.md`.

## 0. Bootstrap

- [x] Branch `feature/scheduled-alarms` off `main`
- [x] Add `.gitignore`, commit "Add gitignore"
- [x] Baseline-commit pre-existing WIP ("Baseline: work in progress on controllers")
- [x] Create `AGENTS.md`, `PLAN.md`, `opencode.json` (injects PLAN.md into every opencode session)

## 1. Spike — IOKit brightness under App Sandbox (blocking go/no-go)

- [x] Single-file swiftc harness: enumerate `IODisplayConnect`,
      `IODisplaySetFloatParameter(kIODisplayBrightnessKey)` min↔max↔restore
- [x] Ad-hoc codesign WITH `com.apple.security.app-sandbox`, run manually,
      observe real display toggle — PASS unsandboxed AND sandboxed
      (container created; all rc=0; 0.0→1.0→restore observed)
- [x] Outcome recorded in AGENTS.md Gotchas → **GO**. Side finding: bare
      executables SIGILL under App Sandbox ⇒ agent must ship as `.app` bundle
      (step 3 updated).

## 2. Shared layer

- [x] `Alarm` model (id, hour, minute, label, isEnabled, weekdays) → "Add alarm model"
- [x] Unit tests (Codable round-trip, validation) → "Add alarm model unit tests"
- [x] `AlarmStore` — JSON in App Group container, injectable directory URL,
      ObservableObject → "Add alarm store"
- [x] Store unit tests → "Add alarm store unit tests"
- [x] `DarwinNotificationCenter` wrapper (post/observe/cancel tokens)
      → "Add darwin notification center wrapper"
- [x] Wrapper unit tests → "Add darwin notification center unit tests"
- [x] GATE: 15/15 tests green on macOS destination AND iOS Simulator
      (iPhone 17 Pro, iOS 26.3.1)

## 3. Xcode project surgery

- [x] `VisualAlarmAgent` target — **.app bundle** (LSUIElement Info.plist,
      sandbox kills bare binaries — see AGENTS.md), macOS-only synchronized folder
- [x] `VisualAlarmRunner.app` target — LSUIElement Info.plist, macOS-only folder
- [x] Copy Files phases: agent + runner → `Contents/Library/LoginItems`;
      plist → `Contents/Library/LaunchAgents`; dependency ordering
      (helpers build before app) — implemented as a macOS-only Run Script
      phase with declared I/O instead: `ValidateEmbeddedBinary` rejects any
      cross-platform CopyFiles phase, and `platformFilters` on PBXBuildFile
      does not apply to copy phases (see AGENTS.md)
- [x] Entitlements files ×3: App Sandbox + App Group `co.denis.VisualAlarm.shared`
- [x] Static agent plist (`Label`, `BundleProgram` → nested agent bundle path,
      `RunAtLoad`, `KeepAlive`) — SMAppService acceptance of nested-bundle
      BundleProgram still verified at step 5 gate
- [x] Schemes for CLI builds/tests (`VisualAlarmAgent`, `VisualAlarmRunner`)
- [x] GATE: `xcodebuild build` green for macOS AND iOS Simulator destinations;
      verified bundle layout (LoginItems ×2 apps, LaunchAgents plist) and iOS
      bundle stays flat

## 4. Runner app (macOS)

- [x] `MacBrightnessController` (IOKit enumerate/get/set/restore-original,
      dlsym'd symbols, `MacBrightnessControlling` protocol as mock seam)
      → "Add mac brightness controller over IOKit" + symbol-resolution tests
- [x] `FlickerEffectController` — async loop, injected clock/interval, cancel =
      restore state exactly once ("Add flicker effect controller with
      injectable clock"); `VirtualClock` test seam drives ticks deterministically
      (sequence + cancellation tests)
- [x] Runner main: reads first enabled alarm from the App Group store for the
      window label, loops system `NSSound("Funk")`, Stop window (no timeout),
      single-instance guard via `NSRunningApplication`, `VA_SMOKE_SECONDS`
      auto-stop hook for automated verification → "Add alarm runner app"
- [x] GATE (manual): launch runner directly — flicker + sound + Stop restores
      original brightness. Verified: flicker confirmed via mid-run IOKit reads
      (1.0↔0.0), sound loops, centered stop window visible, Stop restores;
      two bootstrap/embedding gotchas found & recorded in AGENTS.md

## 5. Agent (macOS)

- [x] `NextFireDateCalculator` pure functions (daily / weekday sets / DST
      edges via `Calendar.nextDate` + `.nextTime`) → "Add next fire date
      calculator"; 8 unit tests incl. spring-forward (skipped 02:30 → 03:00)
      and fall-back (first instance of repeated hour) → test commit
- [x] Scheduler loop — decision engine (`decide`) + `step(sleep:)` iteration:
      ≤30 s capped chunks, catch-up cursor with 60 s grace window, disabled
      alarms ignored, no double-fires ("Add alarm scheduler…"); deterministic
      FakeClock tests (fire-late, stale-skip, chunked wait, store pickup)
      → test commit
- [x] Agent entrypoint — wires store+scheduler, writes fire-request record,
      spawns runner via `RunnerLauncher` (NSWorkspace opener injectable);
      Darwin `.alarmsDidChange` + `NSWorkspace.didWakeNotification` both
      resync; `VA_SMOKE_SECONDS` graceful-exit hook for automated checks
      → "Wire agent entrypoint to scheduler and runner"; spy tests for the
      launcher seam → test commit. Agent target now syncs the shared sources
      folder with membership exceptions
- [ ] GATE (manual E2E): register agent via SMAppService on dev build, schedule
      +2 min alarm, verify firing incl. sleep/wake catch-up; unregister cleanly

## 6. Registration + UI (macOS)

- [x] `SMAppServiceRegistrar` (register/unregister/status mapping, deep link to
      Login Items settings when `.requiresApproval`) → "Add SMAppService
      registrar wrapper"; status-mapping unit tests (incl. `notFound`) → test commit
- [ ] SwiftUI alarm list/editor ViewModels (CRUD → store, enable toggles,
      weekday chips, Test-now button) → commit; ViewModel unit tests → test commit
- [ ] macOS status banner for agent registration state → commit
- [ ] GATE (manual): full flow through UI on Mac

## 7. iOS scheduling + effects

- [ ] `IOSAlarmScheduler` behind protocol — per-weekday/daily repeating
      UNCalendarNotificationTrigger requests, stable identifiers → commit;
      unit tests against mocked notification center → test commit
- [ ] Foreground effect runner — brightness flicker + torch blink (protocol-seam
      TorchController) + haptics; willPresent/tap wiring → commit; loop unit
      tests with mocks → test commit
- [ ] Permission request flow → commit
- [ ] GATE (device checklist): permission prompt, foreground fire = full effect,
      background tap flow opens app + effect, torch blinks on device

## 8. Final sweep

- [ ] Full test suites both platforms green; both build destinations green
- [ ] README update (usage, limitations incl. iOS background constraint)
- [ ] Archive PLAN.md → `docs/archive/`; drop its opencode.json instructions
      entry; promote discoveries into AGENTS.md
