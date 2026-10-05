/**
 * File: SMAppServiceRegistrar.swift
 * Created: 2026-08-23
 */

#if os(macOS)
import Foundation
import ServiceManagement

/// Owns the LaunchAgent registration through SMAppService (macOS 13+) and
/// exposes its state through `AgentRegistering`. The status mapping lives in
/// `AgentRegistrationStatus.map` so it can be unit tested without touching
/// system state. Requires macOS 13; older systems use `LoginItemRegistrar`.
@available(macOS 13.0, *)
@MainActor
final class SMAppServiceRegistrar: AgentRegistering {
    nonisolated static let agentPlistName = "co.denis.VisualAlarm.agent.plist"

    /// Deep link into System Settings › Login Items for the approval flow.
    static let loginItemsSettingsURL = URL(
        string: "x-apple.systempreferences:com.apple.LoginItems-Settings.extension"
    )

    private let plistName: String

    init(plistName: String = SMAppServiceRegistrar.agentPlistName) {
        self.plistName = plistName
    }

    /// Queries the system off-main; safe to call from any executor.
    nonisolated static func queryStatus(
        plistName: String = SMAppServiceRegistrar.agentPlistName
    ) -> AgentRegistrationStatus {
        .map(SMAppService.agent(plistName: plistName).status)
    }

    /// Performs registration off-main and reports the resulting state.
    nonisolated static func performRegistration(
        register: Bool,
        plistName: String = SMAppServiceRegistrar.agentPlistName
    ) async -> AgentRegistrationStatus {
        let service = SMAppService.agent(plistName: plistName)
        do {
            if register {
                try await service.register()
            } else {
                try await service.unregister()
            }
        } catch {
            NSLog("SMAppService \(register ? "register" : "unregister") failed: \(error.localizedDescription)")
        }
        return queryStatus(plistName: plistName)
    }

    func currentStatus() async -> AgentRegistrationStatus {
        let name = plistName
        return await Task.detached {
            SMAppServiceRegistrar.queryStatus(plistName: name)
        }.value
    }

    func setEnabled(_ enabled: Bool) async -> AgentRegistrationStatus {
        let name = plistName
        return await Task.detached {
            await SMAppServiceRegistrar.performRegistration(
                register: enabled,
                plistName: name
            )
        }.value
    }

    var settingsURL: URL? { Self.loginItemsSettingsURL }
}
#endif
