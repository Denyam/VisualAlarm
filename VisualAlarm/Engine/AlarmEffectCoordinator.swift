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
private final class BrightnessBox: @unchecked Sendable {
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
    private let brightnessBox: BrightnessBox
    private let haptics: HapticSignaling
    private let flicker: FlickerEffectController
    private var effectTask: Task<Void, Never>?
    private var originalBrightness: CGFloat?

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
    func start(for alarm: Alarm) {
        start(for: alarm, clock: ContinuousClock())
    }

    func start<C: Clock>(
        for alarm: Alarm,
        clock: C
    ) where C.Instant.Duration == Duration {
        if effectTask == nil {
            originalBrightness = brightnessBox.brightness
        }
        let original = originalBrightness ?? brightnessBox.brightness
        originalBrightness = original
        firingAlarm = alarm

        let box = brightnessBox
        let torch = self.torch
        let haptics = self.haptics

        effectTask?.cancel()
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
            restore: {
                _ = torch.setTorch(on: false)
                box.brightness = original
            }
        )
    }

    func stop() {
        effectTask?.cancel() // cancellation runs restore exactly once
        effectTask = nil
        firingAlarm = nil
    }
}
#endif
