/**
 * File: LoginItemRegistrarTests.swift
 * Created: 2026-10-05
 *
 * Covers the pre-macOS 13 login-item fallback path (separate file so a
 * modern SDK still runs both backend paths).
 */

#if os(macOS)
import Foundation
import Testing

@testable import VisualAlarm

@MainActor
struct LoginItemRegistrarTests {

    /// Isolated defaults domain, cleaned up after each test.
    private final class DefaultsFixture {
        let suiteName: String
        let defaults: UserDefaults

        init() {
            suiteName = "LoginItemRegistrarTests.\(UUID().uuidString)"
            defaults = UserDefaults(suiteName: suiteName)!
        }

        func cleanup() {
            defaults.removePersistentDomain(forName: suiteName)
        }
    }

    /// Records native enable/disable calls for assertions.
    private final class NativeCallRecorder: @unchecked Sendable {
        private let lock = NSLock()
        private var calls: [Bool] = []

        func record(_ enabled: Bool) {
            lock.lock()
            calls.append(enabled)
            lock.unlock()
        }

        var recorded: [Bool] {
            lock.lock()
            defer { lock.unlock() }
            return calls
        }
    }

    private func makeRegistrar(
        fixture: DefaultsFixture,
        recorder: NativeCallRecorder,
        nativeResult: Bool = true
    ) -> LoginItemRegistrar {
        LoginItemRegistrar(
            defaults: fixture.defaults,
            setEnabledNative: { enabled in
                recorder.record(enabled)
                return nativeResult
            }
        )
    }

    @Test func startsNotRegistered() async {
        let fixture = DefaultsFixture()
        defer { fixture.cleanup() }
        let registrar = LoginItemRegistrar(defaults: fixture.defaults)

        let status = await registrar.currentStatus()
        #expect(status == .notRegistered)
    }

    @Test func enablingCallsNativeAPIAndReportsEnabled() async {
        let fixture = DefaultsFixture()
        defer { fixture.cleanup() }
        let recorder = NativeCallRecorder()
        let registrar = makeRegistrar(fixture: fixture, recorder: recorder)

        let status = await registrar.setEnabled(true)
        #expect(status == .enabled)
        #expect(recorder.recorded == [true])
    }

    @Test func disablingAfterEnableCallsNativeAPIAndReportsNotRegistered() async {
        let fixture = DefaultsFixture()
        defer { fixture.cleanup() }
        let recorder = NativeCallRecorder()
        let registrar = makeRegistrar(fixture: fixture, recorder: recorder)

        _ = await registrar.setEnabled(true)
        let status = await registrar.setEnabled(false)
        #expect(status == .notRegistered)
        #expect(recorder.recorded == [true, false])
    }

    @Test func nativeFailureReportsUnknownAndKeepsDefaultsUnchanged() async {
        let fixture = DefaultsFixture()
        defer { fixture.cleanup() }
        let recorder = NativeCallRecorder()
        let registrar = makeRegistrar(
            fixture: fixture,
            recorder: recorder,
            nativeResult: false
        )

        let status = await registrar.setEnabled(true)
        #expect(status == .unknown("SMLoginItemSetEnabled failed"))
        #expect(recorder.recorded == [true])

        let recheck = await registrar.currentStatus()
        #expect(recheck == .notRegistered)
    }

    @Test func intentPersistsAcrossInstances() async {
        let fixture = DefaultsFixture()
        defer { fixture.cleanup() }
        let recorder = NativeCallRecorder()

        let first = makeRegistrar(fixture: fixture, recorder: recorder)
        _ = await first.setEnabled(true)

        // Simulates a relaunch: a fresh registrar over the same defaults.
        let second = LoginItemRegistrar(defaults: fixture.defaults)
        let status = await second.currentStatus()
        #expect(status == .enabled)
    }

    @Test func settingsDeepLinkIsValid() {
        let registrar = LoginItemRegistrar(
            defaults: UserDefaults(suiteName: "LoginItemRegistrarTests.link")!
        )
        #expect(registrar.settingsURL?.scheme == "x-apple.systempreferences")
    }

    @Test func factoryFallsBackToLoginItemWhenSMAppServiceUnavailable() {
        let registrar = AgentRegistrationFactory.make(smAppServiceAvailable: false)
        #expect(registrar is LoginItemRegistrar)
    }
}

@MainActor
struct AgentRegistrationFactoryTests {

    @Test func defaultsToSMAppServiceOnModernOS() {
        // Host runtimes are macOS 13+; the pre-13 branch is compile-checked
        // only (no old-OS runtime obtainable — documented known gap).
        guard #available(macOS 13.0, *) else { return }
        let registrar = AgentRegistrationFactory.make()
        #expect(registrar is SMAppServiceRegistrar)
    }
}
#endif
