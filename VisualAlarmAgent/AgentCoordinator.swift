/**
 * File: AgentCoordinator.swift
 * Created: 2026-08-24
 */

import AppKit
import Foundation

/// Wires the shared alarm store to the scheduler and the runner launcher,
/// refreshing on change signals and wake-from-sleep.
@MainActor
final class AgentCoordinator: NSObject, NSApplicationDelegate {
    private let store = AlarmStore.shared
    private let darwin = DarwinNotificationCenter.shared
    private let launcher: any RunnerLaunching = WorkspaceRunnerLauncher()
    private var scheduler: AlarmScheduler?
    private var loopTask: Task<Void, Never>?
    private var tokens: [DarwinObservationToken] = []

    func applicationDidFinishLaunching(_ notification: Notification) {
        print("agent: started with \(store.alarms.count) alarm(s)")

        let scheduler = AlarmScheduler(
            alarms: { [store] in store.alarms },
            onFire: { [launcher] alarm in
                print("agent: firing '\(alarm.label)'")
                launcher.launch(firingAlarm: alarm)
                fflush(stdout)
            }
        )
        self.scheduler = scheduler
        loopTask = scheduler.run()

        // Reload schedule context when alarms change anywhere.
        tokens.append(darwin.addObserver(for: .alarmsDidChange) { [weak self] in
            Task { @MainActor in self?.resync("alarms changed") }
        })

        // Re-check immediately after the Mac wakes so missed alarms inside
        // the grace window still fire.
        NSWorkspace.shared.notificationCenter.addObserver(
            self,
            selector: #selector(didWake),
            name: NSWorkspace.didWakeNotification,
            object: nil
        )
    }

    func applicationWillTerminate(_ notification: Notification) {
        loopTask?.cancel()
        loopTask = nil
    }

    @objc private func didWake() {
        resync("wake from sleep")
    }

    private func resync(_ reason: String) {
        print("agent: resync (\(reason))")
        // Pick up edits made by other processes before re-anchoring.
        let count = store.load().count
        print("agent: store now has \(count) alarm(s)")
        scheduler?.resync()
    }
}
