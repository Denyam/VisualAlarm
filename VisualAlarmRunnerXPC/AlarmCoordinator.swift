/**
 * File: AlarmCoordinator.swift
 * Created: 2026-10-14
 *
 * Owns the alarm presentation: stop window, looping sound, and the
 * brightness flicker effect, restoring original brightness on termination.
 * Adapted for XPC service — manages its own NSApplication instance.
 */

import AppKit
import Foundation

@MainActor
final class AlarmCoordinator {
    private var window: StopWindow?
    private var sound: LoopingSound?
    private var effectTask: Task<Void, Never>?
    private var app: NSApplication?

    private let brightness = MacBrightnessController()
    private let flicker = FlickerEffectController(interval: 0.5)

    /// Shows the alarm window for the given alarm.
    func showAlarm(alarmID: String, label: String) {
        // Create NSApplication if not already running
        if NSApplication.shared.delegate == nil {
            let app = NSApplication.shared
            app.setActivationPolicy(.accessory)
            self.app = app
        }

        // Single-instance guard within this XPC service
        if window != nil {
            print("runner: alarm already showing, updating label")
            window?.updateLabel(label)
            return
        }

        window = StopWindow(alarmLabel: label)
        window?.show()

        // Activation only sticks once the run loop is running
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

    /// Closes the alarm window and stops all effects.
    func closeAlarm() {
        stopEffects()
        window?.close()
        window = nil
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