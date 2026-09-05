# Fix PR #1 Review Comments — Critical + Bugs (#1–#7)

## Critical #1 — `LoopingSound.shouldLoop` data race
**File**: `VisualAlarmRunner/LoopingSound.swift:33-36`

**Problem**: `shouldLoop` is written from `@MainActor` (via `AlarmCoordinator.stop()`) but read from NSSound's internal delegate thread in `sound(_:didFinishPlaying:)`.

**Fix**: Dispatch delegate callback to main thread before reading `shouldLoop`:
```swift
func sound(_ sound: NSSound, didFinishPlaying finished: Bool) {
    DispatchQueue.main.async { [weak self] in
        guard let self, self.shouldLoop else { return }
        _ = sound.play()
    }
}
```

---

## Critical #2 — `AlarmStore` lacks `@MainActor`
**File**: `VisualAlarm/Model/AlarmStore.swift:12`

**Problem**: Non-isolated `ObservableObject` with mutable state. All callers already run on `@MainActor`.

**Fix**: Add `@MainActor` annotation:
```swift
@MainActor
final class AlarmStore: ObservableObject {
```

---

## Critical #3 — `VirtualClock.sleep()` ignores deadline
**File**: `VisualAlarmTests/VirtualClock.swift:27-39`

**Problem**: Always suspends regardless of whether deadline has already passed.

**Fix**: Check if deadline is already past before suspending:
```swift
func sleep(
    until deadline: ContinuousClock.Instant,
    tolerance: Duration?
) async throws {
    lock.lock()
    let alreadyPast = deadline <= base.advanced(by: elapsed)
    lock.unlock()
    if alreadyPast { return }
    try await withCheckedThrowingContinuation { continuation in
        lock.lock()
        sleepWaiters.append(continuation)
        let parked = suspensionWaiters
        suspensionWaiters.removeAll()
        lock.unlock()
        parked.forEach { $0.resume(returning: ()) }
    }
}
```

---

## Bug #4 — `MacBrightnessController` force-unwraps
**File**: `VisualAlarm/Engine/MacBrightnessController.swift:76,89`

**Problem**: `getParam!` and `setParam!` force-unwrap optionals — fragile if control flow changes.

**Fix**: Use optional chaining:
- Line 76: `getParam!(service, ...)` → `getParam?(service, ...)`
- Line 89: `setParam!(service, ...)` → `setParam?(service, ...)`

---

## Bug #5 — `AlarmFiringOverlay` animation always fires
**File**: `VisualAlarm/View/AlarmFiringOverlay.swift:39`

**Problem**: `.animation(.easeInOut, value: true)` uses constant — triggers on every view update.

**Fix**: Add a state variable to track appearance:
```swift
@State private var appeared = false

var body: some View {
    // ... existing content ...
    .animation(.easeInOut, value: appeared)
    .onAppear { appeared = true }
}
```

---

## Bug #6 — `AlarmScheduler.decide()` recursive
**File**: `VisualAlarm/Engine/AlarmScheduler.swift:57-83`

**Problem**: Recursion per stale alarm risks stack overflow with many alarms.

**Fix**: Convert to a `while` loop:
```swift
func decide(currentTime: Date) -> Decision {
    while true {
        let candidates = alarmsProvider()
            .filter(\.isEnabled)
            .compactMap { alarm -> (Alarm, Date)? in
                NextFireDateCalculator.nextFireDate(
                    for: alarm,
                    after: catchupCursor,
                    calendar: calendar
                ).map { (alarm, $0) }
            }
            .sorted { $0.1 < $1.1 }

        guard let (alarm, target) = candidates.first else {
            return .waitUntil(currentTime.addingTimeInterval(maxChunk))
        }

        if target <= currentTime {
            if currentTime.timeIntervalSince(target) <= graceWindow {
                return .fire(alarm: alarm, target: target)
            }
            catchupCursor = target.addingTimeInterval(1)
            continue  // loop again instead of recurse
        }

        return .waitUntil(target)
    }
}
```

---

## Bug #7 — `ContentView` double-sync
**File**: `VisualAlarm/View/ContentView.swift:80-89`

**Problem**: `.task` and `.onChange(of:)` both fire on initial appearance, running `scheduler.sync` twice.

**Fix**: Guard the initial `onChange` call:
```swift
@State private var hasAppeared = false

.task {
    await requestNotificationPermission()
    await scheduler.sync(alarms: store.alarms)
    NotificationDelegate.shared.coordinator = coordinator
    NotificationDelegate.shared.alarmLookup = { [store] in store.alarms }
    UNUserNotificationCenter.current().delegate = NotificationDelegate.shared
    hasAppeared = true
}
.onChange(of: store.alarms) { _, newAlarms in
    guard hasAppeared else { return }
    Task { await scheduler.sync(alarms: newAlarms) }
}
```

---

## Verification
1. `xcodebuild -project VisualAlarm.xcodeproj -scheme VisualAlarm -destination 'platform=macOS' build`
2. `xcodebuild -project VisualAlarm.xcodeproj -scheme VisualAlarm -destination 'generic/platform=iOS Simulator' build`
3. `xcodebuild test` on both platforms
