/**
 * File: AlarmCoordinator.swift
 * Created: 2026-08-24
 */

import AppKit
import Foundation

/// Owns the alarm presentation: stop window, looping sound, and the
/// brightness flicker effect, restoring original brightness on termination.
@MainActor
final class AlarmCoordinator: NSObject, NSApplicationDelegate {
    private var window: StopWindow?
    private var sound: LoopingSound?
    private var effectTask: Task<Void, Never>?

    private let brightness = MacBrightnessController()
    private let flicker = FlickerEffectController(interval: .milliseconds(500))

    func applicationDidFinishLaunching(_ notification: Notification) {
        print("runner: didFinishLaunching")
        let alarm = currentAlarmLabel()
        window = StopWindow(alarmLabel: alarm)
        window?.show()

        // Activation only sticks once the run loop is running; requesting it
        // before app.run() gets dropped, and without it the Stop button can't
        // receive keyboard focus.
        DispatchQueue.main.async {
            NSApp.activate(ignoringOtherApps: true)
            if let stopWindow = self.window {
                print(
                    "runner: window visible=\(stopWindow.window.isVisible) "
                        + "frame=\(stopWindow.window.frame)"
                )
            }
        }

        startEffects()
    }

    func applicationWillTerminate(_ notification: Notification) {
        stopEffects()
    }

    private func currentAlarmLabel() -> String {
        // The agent records exactly which alarm is ringing.
        if let request = FireRequest.read(), !request.label.isEmpty {
            return request.label
        }
        // Fallback (direct launches during development): first enabled alarm.
        if let alarm = AlarmStore.shared.alarms.first(where: \.isEnabled) {
            return String(format: "%02d:%02d %@", alarm.hour, alarm.minute, alarm.label)
                .trimmingCharacters(in: .whitespaces)
        }
        return "Visual alarm"
    }

    private func startEffects() {
        sound = LoopingSound(named: "Funk")
        let soundLoaded = sound?.isAvailable == true
        print("runner: sound loaded=\(soundLoaded)")
        sound?.play()

        brightness.storeCurrentLevels()
        print(
            "runner: brightness supported=\(brightness.isSupported) "
                + "displays=\(brightness.displayCount)"
        )
        effectTask = flicker.start(
            clock: ContinuousClock(),
            onPhase: { [brightness] in
                if !brightness.setAllDisplays(to: 1.0) {
                    print("runner: set max FAILED")
                }
            },
            offPhase: { [brightness] in
                if !brightness.setAllDisplays(to: 0.0) {
                    print("runner: set min FAILED")
                }
            },
            restore: { [brightness] in brightness.restoreStoredLevels() }
        )
    }

    private func stopEffects() {
        sound?.stop()
        sound = nil
        effectTask?.cancel()
        effectTask = nil
        // The task's own restore runs asynchronously and could lose the race
        // against process exit, so restore synchronously here as well
        // (a second restore is a no-op — originals are released after use).
        brightness.restoreStoredLevels()
    }
}
