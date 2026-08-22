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

- [ ] Single-file swiftc harness: enumerate `IODisplayConnect`,
      `IODisplaySetFloatParameter(kIODisplayBrightnessKey)` min↔max↔restore
- [ ] Ad-hoc codesign WITH `com.apple.security.app-sandbox`, run manually,
      observe real display toggle
- [ ] Record outcome in AGENTS.md Gotchas; if blocked → halt + discuss fallbacks
      (temporary exception entitlement vs. architecture change)

## 2. Shared layer

- [ ] `Alarm` model (id, hour, minute, label, isEnabled, weekdays) → commit "Add alarm model"
- [ ] Unit tests (Codable round-trip, validation) → commit tests
- [ ] `AlarmStore` — JSON in App Group container, injectable directory URL,
      ObservableObject → commit "Add alarm store"
- [ ] Store unit tests (persistence round-trip, concurrent access basics) → commit tests
- [ ] `DarwinNotificationCenter` wrapper (post/observe) → commit
- [ ] Wrapper unit tests (in-process post→observe) → commit tests

## 3. Xcode project surgery

- [ ] `VisualAlarmAgent` target — bare binary, macOS-only synchronized folder
- [ ] `VisualAlarmRunner.app` target — LSUIElement Info.plist, macOS-only folder
- [ ] Copy Files phases: agent → `Contents/MacOS`; runner →
      `Contents/Library/LoginItems`; plist → `Contents/Library/LaunchAgents`;
      dependency ordering (helpers build before app)
- [ ] Entitlements files ×3: App Sandbox + App Group `co.denis.VisualAlarm.shared`
- [ ] Static agent plist (`Label`, `BundleProgram`, `RunAtLoad`, `KeepAlive`)
- [ ] Schemes for CLI builds/tests
- [ ] GATE: `xcodebuild build` green for macOS AND iOS Simulator destinations
      → commit(s)

## 4. Runner app (macOS)

- [ ] `MacBrightnessController` (IOKit enumerate/get/set/restore-original)
      → commit; unit tests with injected service-mock seam → test commit
- [ ] `FlickerEffectController` — async loop, injected clock/interval, cancel =
      restore state → commit; unit tests (sequence, cancellation) → test commit
- [ ] Runner main: reads fire-request from App Group store, loops system
      `NSSound`, Stop window (no timeout), single-instance guard → commit
- [ ] GATE (manual): launch runner directly — flicker + sound + Stop restores
      original brightness

## 5. Agent (macOS)

- [ ] `NextFireDateCalculator` pure functions (daily / weekday sets / DST edges)
      → commit; exhaustive unit tests (fixed time zones) → test commit
- [ ] Scheduler loop — cancellable Task, `ContinuousClock`, ≤30 s chunks,
      reload on Darwin change notification, wake catch-up grace window
      → commit; unit tests with injected clock/fake now (no real sleeps) → test commit
- [ ] Agent entrypoint — wires store+scheduler, writes fire-request record,
      spawns runner via RunnerLauncher protocol → commit; spy-based tests → test commit
- [ ] GATE (manual E2E): register agent via SMAppService on dev build, schedule
      +2 min alarm, verify firing incl. sleep/wake catch-up; unregister cleanly

## 6. Registration + UI (macOS)

- [ ] `SMAppServiceRegistrar` (register/unregister/status mapping, deep link to
      Login Items settings when `.requiresApproval`) → commit; status-mapping
      unit tests → test commit
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
