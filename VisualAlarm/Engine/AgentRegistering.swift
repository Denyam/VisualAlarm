/**
 * File: AgentRegistering.swift
 * Created: 2026-10-05
 */

#if os(macOS)
import Foundation
import ServiceManagement

/// Registration state of the background scheduler agent, as seen by the UI.
enum AgentRegistrationStatus: Equatable {
    case notRegistered
    case enabled
    case requiresApproval
    case unknown(String)

    /// Pure mapping from the SMAppService system type; unit-tested directly.
    @available(macOS 13.0, *)
    static func map(_ status: SMAppService.Status) -> AgentRegistrationStatus {
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

/// Backend-agnostic registration API so macOS 10.15–12 can fall back to the
/// legacy sandboxed login-item API (`SMLoginItemSetEnabled`) while macOS 13+
/// keeps `SMAppService`.
@MainActor
protocol AgentRegistering: AnyObject {
    /// Reads the current state (may round-trip to `smd`; keep off hot paths).
    func currentStatus() async -> AgentRegistrationStatus
    /// Turns registration on/off and returns the resulting state.
    func setEnabled(_ enabled: Bool) async -> AgentRegistrationStatus
    /// Deep link into the system settings pane for this backend.
    var settingsURL: URL? { get }
}

/// Chooses the registration backend for the running OS.
@MainActor
enum AgentRegistrationFactory {
    /// - Parameter smAppServiceAvailable: test seam — the OS-level branch
    ///   cannot be exercised on a modern host, so tests inject it directly.
    static func make(smAppServiceAvailable: Bool? = nil) -> any AgentRegistering {
        let available: Bool
        if let smAppServiceAvailable {
            available = smAppServiceAvailable
        } else if #available(macOS 13.0, *) {
            available = true
        } else {
            available = false
        }
        // Re-check `#available` so a caller claiming availability on an
        // older OS still gets a registrar that exists there.
        if available, #available(macOS 13.0, *) {
            return SMAppServiceRegistrar()
        }
        return LoginItemRegistrar()
    }
}
#endif
