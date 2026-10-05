#if os(macOS)
import AppKit
import Combine
import Foundation

/// Drives the macOS agent-registration banner.
@MainActor
final class AgentRegistrarModel: ObservableObject {
    @Published private(set) var status: AgentRegistrationStatus = .notRegistered

    private let registrar: any AgentRegistering
    private var currentTask: Task<Void, Never>?

    // A default argument would evaluate `make()` in a nonisolated context,
    // so the convenience init provides the default registrar instead.
    init(registrar: any AgentRegistering) {
        self.registrar = registrar
        refresh()
    }

    convenience init() {
        self.init(registrar: AgentRegistrationFactory.make())
    }

    func refresh() {
        // ServiceManagement calls are synchronous XPC round-trips; keep them
        // off the main thread so the first frame can never stall on smd.
        // Cancel any in-flight task so a stale result can't overwrite newer status.
        currentTask?.cancel()
        currentTask = Task { [weak self, registrar] in
            let status = await registrar.currentStatus()
            guard !Task.isCancelled else { return }
            self?.status = status
        }
    }

    func register() {
        mutate(enabled: true)
    }

    func unregister() {
        mutate(enabled: false)
    }

    private func mutate(enabled: Bool) {
        currentTask?.cancel()
        currentTask = Task { [weak self, registrar] in
            let status = await registrar.setEnabled(enabled)
            guard !Task.isCancelled else { return }
            self?.status = status
        }
    }

    func openLoginItemsSettings() {
        guard let url = registrar.settingsURL else { return }
        NSWorkspace.shared.open(url)
    }
}
#endif
