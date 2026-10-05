import Foundation
import Testing

@testable import VisualAlarm

/// Deterministic sleep seam for tests: every sleep suspends until the test
/// calls `tick()`, which resumes all pending sleeps. `waitUntilSuspended()`
/// parks until at least one sleep is pending, so ticks can never fire before
/// the code under test reached its sleep.
///
/// Replaces the former `Clock`-conforming `VirtualClock`: `Clock`,
/// `ContinuousClock`, and `Duration` require macOS 13+ / iOS 16+, above the
/// macOS 10.15 / iOS 15.5 deployment floors.
final class VirtualClock: @unchecked Sendable {
    private let lock = NSLock()
    private var elapsed: TimeInterval = 0
    private var sleepWaiters: [CheckedContinuation<Void, Error>] = []
    private var suspensionWaiters: [CheckedContinuation<Void, Never>] = []

    /// Virtual-time elapsed seconds (advanced by `tick()`).
    var now: TimeInterval {
        lock.lock()
        defer { lock.unlock() }
        return elapsed
    }

    /// The sleep closure to inject into the code under test.
    var sleeper: @Sendable (TimeInterval) async throws -> Void {
        { [self] seconds in
            try await self.sleep(seconds)
        }
    }

    private func sleep(_ seconds: TimeInterval) async throws {
        try await withCheckedThrowingContinuation { continuation in
            lock.lock()
            if seconds <= 0 {
                lock.unlock()
                continuation.resume(returning: ())
                return
            }
            sleepWaiters.append(continuation)
            let parked = suspensionWaiters
            suspensionWaiters.removeAll()
            lock.unlock()
            parked.forEach { $0.resume(returning: ()) }
        }
    }

    /// Resumes every pending sleep once, simulating one interval elapsing.
    func tick() {
        lock.lock()
        elapsed += 1
        let pending = sleepWaiters
        sleepWaiters.removeAll()
        lock.unlock()
        pending.forEach { $0.resume(returning: ()) }
    }

    /// Returns once at least one sleep is pending (or immediately if one
    /// already is).
    func waitUntilSuspended() async {
        lock.lock()
        if !sleepWaiters.isEmpty {
            lock.unlock()
            return
        }
        await withCheckedContinuation { continuation in
            suspensionWaiters.append(continuation)
            lock.unlock()
        }
    }
}
