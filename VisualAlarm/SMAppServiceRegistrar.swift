/**
 * File: SMAppServiceRegistrar.swift
 * Created: 2026-08-23
 */

#if os(macOS)
import Combine
import Foundation
import ServiceManagement

/// Owns the LaunchAgent registration through SMAppService and exposes its
/// state for UI. The status mapping is a pure function so it can be unit
/// tested without touching system state.
@MainActor
final class SMAppServiceRegistrar: ObservableObject {
    enum RegistrationStatus: Equatable {
        case notRegistered
        case enabled
        case requiresApproval
        case unknown(String)

        /// Pure mapping from the system type; unit-tested directly.
        static func map(_ status: SMAppService.Status) -> RegistrationStatus {
            switch status {
            case .notRegistered: return .notRegistered
            case .enabled: return .enabled
            case .requiresApproval: return .requiresApproval
            case .notFound: return .unknown("notFound")
            @unknown default:
                return .unknown("unrecognized rawValue \(status.rawValue)")
            }
        }
    }

    static let agentPlistName = "co.denis.VisualAlarm.agent.plist"

    /// Deep link into System Settings › Login Items for the approval flow.
    static let loginItemsSettingsURL = URL(
        string: "x-apple.systempreferences:com.apple.LoginItems-Settings.extension"
    )

    private let service: SMAppService

    init(plistName: String = SMAppServiceRegistrar.agentPlistName) {
        service = .agent(plistName: plistName)
    }

    var status: RegistrationStatus {
        .map(service.status)
    }

    /// Queries the system off-main; safe to call from any executor.
    nonisolated static func queryStatus(
        plistName: String = SMAppServiceRegistrar.agentPlistName
    ) -> RegistrationStatus {
        .map(SMAppService.agent(plistName: plistName).status)
    }

    /// Performs registration off-main and reports the resulting state.
    nonisolated static func performRegistration(
        register: Bool,
        plistName: String = SMAppServiceRegistrar.agentPlistName
    ) async -> RegistrationStatus {
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

    func register() throws {
        try service.register()
    }

    func unregister() throws {
        try service.unregister()
    }
}
#endif
