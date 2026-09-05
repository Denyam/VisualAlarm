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

    @Test func mapsEverySystemStatus() {
        #expect(
            SMAppServiceRegistrar.RegistrationStatus.map(.notRegistered)
                == .notRegistered
        )
        #expect(
            SMAppServiceRegistrar.RegistrationStatus.map(.enabled)
                == .enabled
        )
        #expect(
            SMAppServiceRegistrar.RegistrationStatus.map(.requiresApproval)
                == .requiresApproval
        )
        #expect(
            SMAppServiceRegistrar.RegistrationStatus.map(.notFound)
                == .unknown("notFound")
        )
    }

    @Test func loginItemsDeepLinkIsValid() {
        #expect(
            SMAppServiceRegistrar.loginItemsSettingsURL?.scheme
                == "x-apple.systempreferences"
        )
    }
}
#endif
