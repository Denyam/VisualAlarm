/**
 * File: AppContainer.swift
 * Created: 2026-10-15
 *
 * Replaces AppGroup.swift: alarms live in the app's own sandbox container.
 */

import Foundation

/// Location of `alarms.json` for the current process.
///
/// Inside the App Sandbox every process resolves its own container, so the
/// app keeps its working copy in the app's container while the agent service
/// persists its authoritative copy in the agent's container; the app mirrors
/// its list to the agent over XPC (`AgentAlarmSync`).
enum AppContainer {
    static let alarmsFilename = "alarms.json"

    /// `Application Support/VisualAlarm`. Inside the App Sandbox this is
    /// `~/Library/Containers/<bundle-id>/Data/Library/Application Support/VisualAlarm`;
    /// outside a sandbox (unit tests, command-line tools) it is the real
    /// Application Support directory.
    static var directory: URL {
        let base = FileManager.default.urls(
            for: .applicationSupportDirectory,
            in: .userDomainMask
        )[0]
        let directory = base.appendingPathComponent(
            "VisualAlarm",
            isDirectory: true
        )
        try? FileManager.default.createDirectory(
            at: directory,
            withIntermediateDirectories: true
        )
        return directory
    }
}
