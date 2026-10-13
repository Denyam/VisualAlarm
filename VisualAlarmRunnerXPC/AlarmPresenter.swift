/**
 * File: AlarmPresenter.swift
 * Created: 2026-10-13
 *
 * Owns the alarm presentation: stop window, looping sound and brightness
 * flicker, restoring the original brightness when the alarm is dismissed.
 */

import AppKit
import Foundation

@MainActor
final class AlarmPresenter {
    private var window: StopWindow?
    private var sound: LoopingSound?
    private var effectTask: Task<Void, Never>?

    private let brightness = MacBrightnessController()
    private let flicker = FlickerEffectController(interval: 0.5)

    func present(alarm: Alarm) {
        // Re-presenting (a second alarm while one is up) replaces the window.
        dismissEffects()

        let label = alarm.label.isEmpty ? "Visual alarm" : alarm.label
        let window = StopWindow(alarmLabel: label)
        window.onStop = { [weak self] in
            self?.onStopRequested()
        }
        window.show()
        self.window = window

        // Activation only sticks once the run loop is running; requesting it
        // earlier is dropped, and without it the Stop button cannot take focus.
        DispatchQueue.main.async { [weak self] in
            NSApp.activate(ignoringOtherApps: true)
            guard let stopWindow = self?.window else { return }
            print(
                "runner: window visible=\(stopWindow.window.isVisible) "
                    + "frame=\(stopWindow.window.frame)"
            )
        }

        startEffects()
    }

    func dismiss() {
        dismissEffects()
        window?.window.close()
        window = nil
    }

    private func onStopRequested() {
        print("runner: stop requested")
        dismiss()
        NSApp.terminate(nil)
    }

    private func startEffects() {
        sound = LoopingSound(named: "Funk")
        print("runner: sound loaded=\(sound?.isAvailable == true)")
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

    private func dismissEffects() {
        sound?.stop()
        sound = nil
        effectTask?.cancel()
        effectTask = nil
        // The task's own restore runs asynchronously and could lose the race
        // against teardown, so restore synchronously here too (a second restore
        // is a no-op — originals are released after use).
        brightness.restoreStoredLevels()
    }
}