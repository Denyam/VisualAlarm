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

    func register() throws {
        try service.register()
    }

    func unregister() throws {
        try service.unregister()
    }
}
#endif
