#if os(macOS)
import AppKit
import Combine
import Foundation

/// Drives the macOS agent-registration banner.
@MainActor
final class AgentRegistrarModel: ObservableObject {
    @Published private(set) var status: SMAppServiceRegistrar.RegistrationStatus =
        .notRegistered

    private let plistName: String

    init(plistName: String = SMAppServiceRegistrar.agentPlistName) {
        self.plistName = plistName
        refresh()
    }

    func refresh() {
        // ServiceManagement calls are synchronous XPC round-trips; keep them
        // off the main thread so the first frame can never stall on smd.
        let name = plistName
        Task { [weak self] in
            let status = await Task.detached {
                SMAppServiceRegistrar.queryStatus(plistName: name)
            }.value
            self?.status = status
        }
    }

    func register() {
        mutate(register: true)
    }

    func unregister() {
        mutate(register: false)
    }

    private func mutate(register: Bool) {
        let name = plistName
        Task { [weak self] in
            let status = await Task.detached {
                await SMAppServiceRegistrar.performRegistration(
                    register: register,
                    plistName: name
                )
            }.value
            self?.status = status
        }
    }

    func openLoginItemsSettings() {
        guard let url = SMAppServiceRegistrar.loginItemsSettingsURL else { return }
        NSWorkspace.shared.open(url)
    }
}
#endif
