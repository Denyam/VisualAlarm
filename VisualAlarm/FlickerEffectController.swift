/**
 * File: FlickerEffectController.swift
 * Created: 2026-08-22
 */

import Foundation

/// Drives an alarm's visual effect: alternates between the `on` and `off`
/// states every `interval` until the started task is cancelled, then invokes
/// `restore` exactly once so original brightness/torch state comes back.
///
/// The clock is injectable for deterministic tests (`VirtualClock`): sleeps
/// resume when the test ticks virtual time forward.
struct FlickerEffectController {
    var interval = Duration.milliseconds(500)

    @discardableResult
    func start<C: Clock>(
        clock: C,
        onPhase: @escaping @Sendable () async -> Void,
        offPhase: @escaping @Sendable () async -> Void,
        restore: @escaping @Sendable () async -> Void
    ) -> Task<Void, Never> where C.Instant.Duration == Duration {
        Task(priority: .userInitiated) {
            var showingOnPhase = true
            await onPhase()
            while !Task.isCancelled {
                try? await Task.sleep(
                    until: clock.now.advanced(by: interval),
                    tolerance: nil,
                    clock: clock
                )
                guard !Task.isCancelled else { break }
                if showingOnPhase {
                    await offPhase()
                } else {
                    await onPhase()
                }
                showingOnPhase.toggle()
            }
            await restore()
        }
    }
}
