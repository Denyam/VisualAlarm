/**
 * File: SMAppServiceRegistrarTests.swift
 * Created: 2026-08-23
 */

#if os(macOS)
import ServiceManagement
import Testing

@testable import VisualAlarm

@MainActor
struct SMAppServiceRegistrarTests {

    // Swift Testing cannot attach @Test to availability-gated functions, so
    // each test skips itself below macOS 13 instead of being gated.
    @Test func mapsEverySystemStatus() {
        guard #available(macOS 13.0, *) else { return }
        #expect(
            AgentRegistrationStatus.map(.notRegistered)
                == .notRegistered
        )
        #expect(
            AgentRegistrationStatus.map(.enabled)
                == .enabled
        )
        #expect(
            AgentRegistrationStatus.map(.requiresApproval)
                == .requiresApproval
        )
        #expect(
            AgentRegistrationStatus.map(.notFound)
                == .unknown("notFound")
        )
    }

    @Test func loginItemsDeepLinkIsValid() {
        guard #available(macOS 13.0, *) else { return }
        #expect(
            SMAppServiceRegistrar.loginItemsSettingsURL?.scheme
                == "x-apple.systempreferences"
        )
    }

    @Test func factoryReturnsSMAppServiceRegistrarWhenAvailable() {
        guard #available(macOS 13.0, *) else { return }
        let registrar = AgentRegistrationFactory.make(smAppServiceAvailable: true)
        #expect(registrar is SMAppServiceRegistrar)
        #expect(registrar.settingsURL?.scheme == "x-apple.systempreferences")
    }
}
#endif
