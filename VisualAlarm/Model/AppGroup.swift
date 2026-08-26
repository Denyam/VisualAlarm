/**
 * File: AppGroup.swift
 * Created: 2026-08-24
 */

import Foundation

/// Identifies the shared App Group container used by the app, agent, and
/// runner processes. The identifier must stay team-prefixed AND begin with
/// "group." (required by provisioning for real-device builds; see AGENTS.md).
enum AppGroup {
    static let identifier = "group.ETFKU52LQ6.co.denis.VisualAlarm.shared"
    static let alarmsFilename = "alarms.json"

    static var containerURL: URL? {
        FileManager.default.containerURL(
            forSecurityApplicationGroupIdentifier: identifier
        )
    }

    /// Directory shared by app, agent, and runner; falls back to Application
    /// Support when no container is available (unsandboxed tools, tests).
    static var directory: URL {
        if let container = containerURL {
            return container
        }
        let fallback = FileManager.default.urls(
            for: .applicationSupportDirectory,
            in: .userDomainMask
        )[0].appendingPathComponent("VisualAlarm", isDirectory: true)
        try? FileManager.default.createDirectory(
            at: fallback,
            withIntermediateDirectories: true
        )
        return fallback
    }
}
