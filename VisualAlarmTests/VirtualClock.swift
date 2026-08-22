/**
 * File: VirtualClock.swift
 * Created: 2026-08-22
 */

import Foundation

/// Deterministic `Clock` for tests: every sleep suspends until the test calls
/// `tick()`, which resumes all pending sleeps and advances virtual time.
final class VirtualClock: Clock, @unchecked Sendable {
    typealias Instant = ContinuousClock.Instant

    let minimumResolution: Duration = .zero

    private let lock = NSLock()
    private let base = ContinuousClock.now
    private var elapsed: Duration = .zero
    private var waiters: [CheckedContinuation<Void, Error>] = []

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
            waiters.append(continuation)
            lock.unlock()
        }
    }

    /// Resumes every pending sleep once, simulating one interval elapsing.
    func tick() {
        lock.lock()
        elapsed += .seconds(1)
        let pending = waiters
        waiters.removeAll()
        lock.unlock()
        pending.forEach { $0.resume(returning: ()) }
    }
}
