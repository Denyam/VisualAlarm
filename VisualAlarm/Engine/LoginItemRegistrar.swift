/**
 * File: LoginItemRegistrar.swift
 * Created: 2026-10-05
 */

#if os(macOS)
import Foundation
import ServiceManagement

/// Fallback registrar for macOS 10.15–12, where `SMAppService` does not
/// exist. Uses the legacy login-item API: the agent bundle is already
/// embedded at `Contents/Library/LoginItems`, and `SMLoginItemSetEnabled`
/// only ever touches that bundle (no elevated helper, App Sandbox safe).
///
/// The API offers no status query, so the user's intent is mirrored into
/// defaults; the native call is injectable for tests.
@MainActor
final class LoginItemRegistrar: AgentRegistering {
    nonisolated static let agentBundleID = "co.denis.VisualAlarm.agent"
    nonisolated static let enabledDefaultsKey = "VAAgentRegistrationEnabled"

    /// Deep link into System Preferences › Users & Groups (pre-Ventura home
    /// of the Login Items list).
    static let loginItemsSettingsURL = URL(
        string: "x-apple.systempreferences:com.apple.preferences.users"
    )

    private let defaults: UserDefaults
    private let setEnabledNative: @Sendable (Bool) -> Bool

    init(
        defaults: UserDefaults = .standard,
        setEnabledNative: @escaping @Sendable (Bool) -> Bool = { enabled in
            SMLoginItemSetEnabled(
                LoginItemRegistrar.agentBundleID as CFString,
                enabled
            )
        }
    ) {
        self.defaults = defaults
        self.setEnabledNative = setEnabledNative
    }

    func currentStatus() async -> AgentRegistrationStatus {
        defaults.bool(forKey: Self.enabledDefaultsKey) ? .enabled : .notRegistered
    }

    func setEnabled(_ enabled: Bool) async -> AgentRegistrationStatus {
        guard setEnabledNative(enabled) else {
            return .unknown("SMLoginItemSetEnabled failed")
        }
        defaults.set(enabled, forKey: Self.enabledDefaultsKey)
        return enabled ? .enabled : .notRegistered
    }

    var settingsURL: URL? { Self.loginItemsSettingsURL }
}
#endif
