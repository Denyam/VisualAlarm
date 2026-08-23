/**
 * File: AgentRegistrarModel.swift
 * Created: 2026-08-23
 */

#if os(macOS)
import AppKit
import Combine
import Foundation

/// Drives the macOS agent-registration banner.
@MainActor
final class AgentRegistrarModel: ObservableObject {
    @Published private(set) var status: SMAppServiceRegistrar.RegistrationStatus =
        .notRegistered

    private let registrar: SMAppServiceRegistrar

    init(registrar: SMAppServiceRegistrar? = nil) {
        self.registrar = registrar ?? SMAppServiceRegistrar()
        refresh()
    }

    func refresh() {
        status = registrar.status
    }

    func register() {
        do {
            try registrar.register()
        } catch {
            NSLog("register failed: \(error.localizedDescription)")
        }
        refresh()
    }

    func unregister() {
        do {
            try registrar.unregister()
        } catch {
            NSLog("unregister failed: \(error.localizedDescription)")
        }
        refresh()
    }

    func openLoginItemsSettings() {
        guard let url = SMAppServiceRegistrar.loginItemsSettingsURL else { return }
        NSWorkspace.shared.open(url)
    }
}
#endif
