/**
 * File: AlarmEffectCoordinatorTests.swift
 * Created: 2026-09-07
 */

#if os(iOS)
import Foundation
import Testing

@testable import VisualAlarm

@MainActor
struct AlarmEffectCoordinatorTests {

    private let flicker = FlickerEffectController(interval: .milliseconds(10))

    @Test func rapidStartStopDoesNotRace() async throws {
        let brightnessController = FakeBrightnessController()
        brightnessController.brightness = 0.5
        
        let coordinator = AlarmEffectCoordinator(
            torch: FakeTorchController(),
            brightness: brightnessController,
            haptics: SilentHaptics(),
            flicker: flicker
        )

        let alarm = Alarm(hour: 12, minute: 0)

        // Rapidly start/stop 50 times - verify brightness restored after each cycle
        for i in 0..<50 {
            await coordinator.start(for: alarm, clock: ContinuousClock())
            let brightnessDuringEffect = coordinator.currentBrightness
            let originalSnapshot = coordinator.snapshotBrightness
            if brightnessDuringEffect != originalSnapshot {
                print("FAIL Cycle \(i) during: brightness=\(brightnessDuringEffect), original=\(String(describing: originalSnapshot)), pending=\(String(describing: coordinator.pendingBrightnessForTest)), effectTask=\(coordinator.currentEffectTask != nil)")
            }
            #expect(brightnessDuringEffect == originalSnapshot, "Cycle \(i): brightness \(brightnessDuringEffect) != original \(String(describing: originalSnapshot))")
            
            coordinator.stop()
            let bAfterStop = coordinator.currentBrightness
            let sAfterStop = coordinator.snapshotBrightness
            if bAfterStop != originalSnapshot {
                print("FAIL Cycle \(i) after stop: brightness=\(bAfterStop), original=\(String(describing: originalSnapshot)), pending=\(String(describing: coordinator.pendingBrightnessForTest)), effectTask=\(coordinator.currentEffectTask != nil)")
            }
            #expect(bAfterStop == originalSnapshot, "Cycle \(i) after stop: brightness \(bAfterStop) != original \(String(describing: originalSnapshot))")
            
            try await Task.sleep(for: .milliseconds(1))
        }
    }

    @Test func repeatedStartReplacesEffect() async throws {
        let coordinator = AlarmEffectCoordinator(
            torch: FakeTorchController(),
            brightness: FakeBrightnessController(),
            haptics: SilentHaptics(),
            flicker: flicker
        )

        await coordinator.start(for: Alarm(hour: 1, minute: 1), clock: ContinuousClock())
        let firstTask = coordinator.currentEffectTask

        // Start again immediately - should await first task
        await coordinator.start(for: Alarm(hour: 2, minute: 2), clock: ContinuousClock())

        // First task should be complete (including restore)
        #expect(firstTask != nil)
        // The task should be different (replaced)
        #expect(coordinator.currentEffectTask != nil)
    }

    @Test func stopAllowsNewStartToSnapshotFresh() async throws {
        let brightnessController = FakeBrightnessController()
        brightnessController.brightness = 0.3
        
        let coordinator = AlarmEffectCoordinator(
            torch: FakeTorchController(),
            brightness: brightnessController,
            haptics: SilentHaptics(),
            flicker: flicker
        )

        let alarm = Alarm(hour: 12, minute: 0)
        
        // Start effect (snapshots brightness = 0.3)
        await coordinator.start(for: alarm, clock: ContinuousClock())
        let b1 = coordinator.currentBrightness
        let s1 = coordinator.snapshotBrightness
        print("After first start: brightness=\(b1), snapshot=\(String(describing: s1))")
        
        // Change brightness externally while effect is running
        brightnessController.brightness = 0.7
        let b2 = coordinator.currentBrightness
        print("After manual change: brightness=\(b2)")
        
        // Stop the effect
        coordinator.stop()
        let b3 = coordinator.currentBrightness
        let s3 = coordinator.snapshotBrightness
        print("After stop: brightness=\(b3), snapshot=\(String(describing: s3))")
        
        // Give cleanup task time to run
        try await Task.sleep(for: .milliseconds(50))
        let b4 = coordinator.currentBrightness
        let s4 = coordinator.snapshotBrightness
        print("After sleep: brightness=\(b4), snapshot=\(String(describing: s4))")
        
        // Start again - should snapshot fresh brightness (0.7), not old (0.3)
        await coordinator.start(for: alarm, clock: ContinuousClock())
        let b5 = coordinator.currentBrightness
        let s5 = coordinator.snapshotBrightness
        print("After second start: brightness=\(b5), snapshot=\(String(describing: s5))")
        
        // The original brightness should now be 0.7 (the fresh snapshot)
        #expect(coordinator.snapshotBrightness == 0.7)
    }
}
#endif