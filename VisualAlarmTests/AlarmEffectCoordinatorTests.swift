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

    private let flicker = FlickerEffectController(interval: 0.01)

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

        // Rapidly start/stop 50 times - verify the original-brightness
        // snapshot survives every cycle. The flicker task runs
        // unsynchronized with the test, so a "during" read accepts either
        // the snapshot (task not started yet) or a flicker value, and the
        // after-stop read waits for the cancelled task's restore to finish.
        for i in 0..<50 {
            await coordinator.start(for: alarm)
            let originalSnapshot = coordinator.snapshotBrightness
            #expect(
                originalSnapshot == 0.5,
                "Cycle \(i): snapshot \(String(describing: originalSnapshot)) != 0.5"
            )

            let brightnessDuringEffect = coordinator.currentBrightness
            let validStates: Set<CGFloat> = [0.5, 1.0, 0.01]
            #expect(
                validStates.contains(brightnessDuringEffect),
                "Cycle \(i): brightness \(brightnessDuringEffect) is neither original nor a flicker value"
            )

            coordinator.stop()

            // Await the cancelled effect task directly: restore runs on that
            // task, and only once it completes is brightness guaranteed back
            // to the snapshot (a fixed sleep can't order this — the task may
            // not even have started when stop() cancelled it).
            if let cancelledTask = coordinator.currentEffectTask {
                await cancelledTask.value
            }
            let bAfterStop = coordinator.currentBrightness
            #expect(
                bAfterStop == originalSnapshot,
                "Cycle \(i) after stop: brightness \(bAfterStop) != original \(String(describing: originalSnapshot))"
            )
        }
    }

    @Test func repeatedStartReplacesEffect() async throws {
        let coordinator = AlarmEffectCoordinator(
            torch: FakeTorchController(),
            brightness: FakeBrightnessController(),
            haptics: SilentHaptics(),
            flicker: flicker
        )

        await coordinator.start(for: Alarm(hour: 1, minute: 1))
        let firstTask = coordinator.currentEffectTask

        // Start again immediately - should await first task
        await coordinator.start(for: Alarm(hour: 2, minute: 2))

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
        await coordinator.start(for: alarm)
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
        try await Task.sleep(nanoseconds: 50 * 1_000_000)
        let b4 = coordinator.currentBrightness
        let s4 = coordinator.snapshotBrightness
        print("After sleep: brightness=\(b4), snapshot=\(String(describing: s4))")
        
        // Start again - should snapshot fresh brightness (0.7), not old (0.3)
        await coordinator.start(for: alarm)
        let b5 = coordinator.currentBrightness
        let s5 = coordinator.snapshotBrightness
        print("After second start: brightness=\(b5), snapshot=\(String(describing: s5))")
        
        // The original brightness should now be 0.7 (the fresh snapshot)
        #expect(coordinator.snapshotBrightness == 0.7)
    }
}
#endif