import Foundation
import Testing

@testable import VisualAlarm

/// Deterministic `Clock` for tests: every sleep suspends until the test calls
/// `tick()`, which resumes all pending sleeps and advances virtual time.
/// `waitUntilSuspended()` parks until at least one sleep is pending, so ticks
/// can never fire before the code under test reached its sleep.
final class VirtualClock: Clock, @unchecked Sendable {
    typealias Instant = ContinuousClock.Instant

    let minimumResolution: Duration = .zero

    private let lock = NSLock()
    private let base = ContinuousClock.now
    private var elapsed: Duration = .zero
    private var sleepWaiters: [CheckedContinuation<Void, Error>] = []
    private var suspensionWaiters: [CheckedContinuation<Void, Never>] = []

    var now: ContinuousClock.Instant {
        lock.lock()
        defer { lock.unlock() }
        return base.advanced(by: elapsed)
    }

    func sleep(
        until deadline: ContinuousClock.Instant,
        tolerance: Duration?
    ) async throws {
        try await withCheckedThrowingContinuation { continuation in
            lock.lock()
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
        elapsed += .seconds(1)
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
