/**
 * File: AppGroup.swift
 * Created: 2026-08-24
 */

import Foundation

/// Locates the directory holding the shared alarm state.
///
/// The App Group entitlement has been removed from the build (see
/// `Support/VisualAlarm.entitlements`), so `containerURL(forSecurityApplicationGroupIdentifier:)`
/// always returns nil and each sandboxed process gets its own container instead
/// of a shared one. The path below is therefore resolved explicitly rather than
/// through App Support's container-relative lookup, so that the app, the agent
/// XPC service, and the runner XPC service all compute the *same* absolute path.
///
/// KNOWN LIMITATION: under App Sandbox that absolute path is private to each
/// process, so the helpers do not actually observe the app's `alarms.json`
/// while sandboxed. It resolves correctly when the sandbox is off (e.g. an
/// ad-hoc local build with `ENABLE_APP_SANDBOX = NO`). Restoring shared state
/// between processes while sandboxed requires re-adding the App Group
/// entitlement, which in turn requires a real signing identity.
enum AppGroup {
    static let identifier = "group.ETFKU52LQ6.co.denis.VisualAlarm.shared"
    static let alarmsFilename = "alarms.json"

    /// Absolute, container-independent location shared by all three processes.
    static var directory: URL {
        let base = FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent(
                "Library/Application Support/VisualAlarm",
                isDirectory: true
            )
        try? FileManager.default.createDirectory(
            at: base,
            withIntermediateDirectories: true
        )
        return base
    }
}