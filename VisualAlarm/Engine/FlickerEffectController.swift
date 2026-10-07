/**
 * File: FlickerEffectController.swift
 * Created: 2026-08-22
 */

import Foundation

/// Drives an alarm's visual effect: alternates between the `on` and `off`
/// states every `interval` seconds until the started task is cancelled, then
/// invokes `restore` exactly once so original brightness/torch state comes
/// back.
///
/// The sleep is injectable for deterministic tests (`VirtualClock`): sleeps
/// resume when the test ticks virtual time forward. Time is plain
/// `TimeInterval` seconds (not `Duration`) because the deployment floors are
/// macOS 10.15 / iOS 15.5.
struct FlickerEffectController {
    var interval: TimeInterval = 0.5

    /// Injected sleep seam; defaults to the real clock.
    var sleep: @Sendable (_ seconds: TimeInterval) async throws -> Void = {
        try await Task.sleep(seconds: $0)
    }

    @discardableResult
    func start(
        onPhase: @escaping @Sendable () async -> Void,
        offPhase: @escaping @Sendable () async -> Void,
        restore: @escaping @Sendable () async -> Void
    ) -> Task<Void, Never> {
        Task(priority: .userInitiated) {
            var showingOnPhase = true
            await onPhase()
            while !Task.isCancelled {
                try? await sleep(interval)
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
