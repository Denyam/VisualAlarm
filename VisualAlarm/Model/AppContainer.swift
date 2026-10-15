/**
 * File: AppContainer.swift
 * Created: 2026-10-15
 *
 * Replaces AppGroup.swift: alarms live in the app's own sandbox container.
 */

import Foundation

/// Location of the alarm data shared between the main app and the XPC
/// services embedded in its bundle.
///
/// The XPC services run inside the app's sandbox, so `Application Support`
/// resolves to the same container directory in every process — no App Group
/// entitlement is needed for sharing `alarms.json`.
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
