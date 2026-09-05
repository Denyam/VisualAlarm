/**
 * File: AlarmScheduler.swift
 * Created: 2026-08-23
 */

import Foundation

/// Fires alarms at their due times. The loop re-evaluates the alarm list in
/// chunks of at most `maxChunk` seconds so wall-clock edits, store changes,
/// and wake-from-sleep are picked up quickly; alarms missed by no more than
/// `graceWindow` still fire (late).
///
/// All time flows through injected closures (`now`, `sleep`, `alarms`),
/// keeping the engine deterministic under test without real sleeping.
final class AlarmScheduler: @unchecked Sendable {
    enum Decision {
        /// An alarm is due: fire it and consume its target instant.
        case fire(alarm: Alarm, target: Date)
        /// Sleep until the given instant (capped externally).
        case waitUntil(Date)
    }

    private let alarmsProvider: @Sendable () -> [Alarm]
    private let onFire: @Sendable (Alarm) -> Void
    private let now: @Sendable () -> Date
    private let calendar: Calendar

    /// Alarms missed by more than this many seconds are skipped silently.
    let graceWindow: TimeInterval
    /// Upper bound for a single sleep, keeping the loop responsive.
    let maxChunk: TimeInterval

    /// Only instants strictly after this cursor are considered; it advances
    /// past every consumed target so nothing fires twice.
    private var catchupCursor: Date
    private let schedulerLock = NSLock()

    init(
        alarms: @escaping @Sendable () -> [Alarm],
        now: @escaping @Sendable () -> Date = Date.init,
        calendar: Calendar = .current,
        graceWindow: TimeInterval = 60,
        maxChunk: TimeInterval = 30,
        startingFrom: Date? = nil,
        onFire: @escaping @Sendable (Alarm) -> Void
    ) {
        self.alarmsProvider = alarms
        self.now = now
        self.calendar = calendar
        self.graceWindow = graceWindow
        self.maxChunk = maxChunk
        self.catchupCursor = startingFrom ?? now().addingTimeInterval(-graceWindow)
        self.onFire = onFire
    }

    /// The earliest upcoming instant across all enabled alarms, considering
    /// the grace window. Internal for tests.
    func decide(currentTime: Date) -> Decision {
        schedulerLock.lock()
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

        while true {
            guard let (alarm, target) = candidates.first else {
                schedulerLock.unlock()
                return .waitUntil(currentTime.addingTimeInterval(maxChunk))
            }

            if target <= currentTime {
                if currentTime.timeIntervalSince(target) <= graceWindow {
                    schedulerLock.unlock()
                    return .fire(alarm: alarm, target: target)
                }
                // Stale beyond grace: skip it and look again immediately.
                catchupCursor = target.addingTimeInterval(1)
                continue
            }

            schedulerLock.unlock()
            return .waitUntil(target)
        }
    }

    /// One loop iteration: evaluate, fire what is due or sleep toward the
    /// next instant using the provided async sleep.
    func step(
        sleep: @Sendable (Duration) async throws -> Void
    ) async {
        let currentTime = now()

        switch decide(currentTime: currentTime) {
        case .fire(let alarm, let target):
            catchupCursor = target.addingTimeInterval(1)
            onFire(alarm)

        case .waitUntil(let target):
            let remaining = max(0, target.timeIntervalSince(currentTime))
            let bounded = min(remaining, maxChunk)
            try? await sleep(Duration.seconds(bounded))
        }
    }

    /// Cancellable driver loop; cancel the returned task to stop.
    func run() -> Task<Void, Never> {
        Task {
            while !Task.isCancelled {
                await step { duration in
                    try await Task.sleep(for: duration, clock: .continuous)
                }
            }
        }
    }

    /// Re-anchors the catch-up window to right now (used when the alarm store
    /// changed or the Mac woke from sleep).
    func resync() {
        catchupCursor = now().addingTimeInterval(-graceWindow)
    }
}
