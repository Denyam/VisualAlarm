/**
 * File: AlarmEffectCoordinator.swift
 * Created: 2026-08-25
 */

#if os(iOS)
import Combine
import Foundation
import UIKit

/// A reference box that allows `@Sendable` closures to mutate
/// a `ScreenBrightnessControlling` value held by the coordinator.
final class BrightnessBox: @unchecked Sendable {
    var controller: any ScreenBrightnessControlling
    init(_ controller: any ScreenBrightnessControlling) { self.controller = controller }
    var brightness: CGFloat {
        get { controller.brightness }
        set { controller.brightness = newValue }
    }
}

/// Runs the full visual alarm on iOS: brightness flicker, torch blink, and
/// haptics, until stopped. Original screen brightness is restored on stop.
@MainActor
final class AlarmEffectCoordinator: ObservableObject {
    @Published private(set) var firingAlarm: Alarm?

    private let torch: TorchControlling
    let brightnessBox: BrightnessBox
    private let haptics: HapticSignaling
    private let flicker: FlickerEffectController
    private var effectTask: Task<Void, Never>?
    private var originalBrightness: CGFloat?
    private var pendingBrightness: CGFloat?

    /// Test-only accessor for current brightness
    var currentBrightness: CGFloat { brightnessBox.brightness }

    /// Test-only accessor for original brightness snapshot
    var snapshotBrightness: CGFloat? { originalBrightness }

    /// Test-only accessor for pending brightness
    var pendingBrightnessForTest: CGFloat? { pendingBrightness }

    /// Test-only accessor for effect task
    var currentEffectTask: Task<Void, Never>? { effectTask }

    init(
        torch: TorchControlling = TorchController(),
        brightness: ScreenBrightnessControlling = BrightnessController(),
        haptics: HapticSignaling = AlertHaptics(),
        flicker: FlickerEffectController = FlickerEffectController(
            interval: .milliseconds(500)
        )
    ) {
        self.torch = torch
        self.brightnessBox = BrightnessBox(brightness)
        self.haptics = haptics
        self.flicker = flicker
    }

    /// Starts the effect for the given alarm. Repeated calls replace the
    /// running effect without disturbing the original brightness snapshot.
    func start(for alarm: Alarm) async {
        await start(for: alarm, clock: ContinuousClock())
    }

    func start<C: Clock>(
        for alarm: Alarm,
        clock: C
    ) async where C.Instant.Duration == Duration {
        // Priority: pending brightness (set by stop) > original brightness > current brightness
        let brightnessSnapshot = pendingBrightness ?? originalBrightness ?? brightnessBox.brightness
        pendingBrightness = nil
        originalBrightness = brightnessSnapshot
        firingAlarm = alarm

        let box = brightnessBox
        let torch = self.torch
        let haptics = self.haptics

        // Cancel and AWAIT old task to fully complete (including restore)
        if let oldTask = effectTask {
            oldTask.cancel()
            await oldTask.value
        }

        effectTask = flicker.start(
            clock: clock,
            onPhase: {
                _ = torch.setTorch(on: true)
                box.brightness = 1.0
                haptics.fire()
            },
            offPhase: {
                _ = torch.setTorch(on: false)
                box.brightness = 0.01
            },
            restore: { [weak self] in
                _ = torch.setTorch(on: false)
                guard let self else { return }
                box.brightness = self.originalBrightness ?? 0.5
            }
        )
    }

    func stop() {
        effectTask?.cancel()
        
        // Capture brightness for next start: if current is a flicker value (1.0 or 0.01),
        // use original to preserve it; otherwise user may have changed it, so use current.
        let current = brightnessBox.brightness
        let isFlickerValue = (current >= 0.99 && current <= 1.01) || (current >= 0.0 && current <= 0.02)
        pendingBrightness = isFlickerValue ? originalBrightness : current
        
        // Clean up effectTask after task completes (non-blocking)
        Task {
            await effectTask?.value
            effectTask = nil
        }
        
        // Reset brightness snapshot so next start() captures fresh value
        originalBrightness = nil
        firingAlarm = nil
    }
}
#endif
