/**
 * File: TaskSleep.swift
 * Created: 2026-10-05
 */

import Foundation

extension Task where Success == Never, Failure == Never {
    /// Sleeps for the given number of seconds.
    ///
    /// Deployment floors are macOS 10.15 / iOS 15.5, where `Duration`,
    /// `Clock`, and `Task.sleep(for:)` do not exist (macOS 13+ / iOS 16+),
    /// so all scheduling code goes through this nanoseconds-based helper.
    static func sleep(seconds: TimeInterval) async throws {
        try await Task.sleep(
            nanoseconds: UInt64(max(0, seconds) * 1_000_000_000)
        )
    }
}
