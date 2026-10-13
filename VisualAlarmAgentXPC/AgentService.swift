/**
 * File: AgentService.swift
 * Created: 2026-10-13
 *
 * Wires the shared alarm store to the scheduler and drives the runner service
 * over XPC. Registered once as a launchd agent via SMAppService, so launchd
 * keeps it alive for the whole login session — independent of the main app.
 */

import AppKit
import Foundation

@MainActor
final class AgentService: NSObject {
    private let store = AlarmStore.shared
    private let darwin = DarwinNotificationCenter.shared
    private var scheduler: AlarmScheduler?
    private var loopTask: Task<Void, Never>?
    private var tokens: [DarwinObservationToken] = []
    private let runner: RunnerXPCClient?

    init(runner: RunnerXPCClient? = RunnerXPCClient()) {
        self.runner = runner
        super.init()
    }

    func start() {
        print("agent: started with \(store.alarms.count) alarm(s)")

        let runner = self.runner
        let scheduler = AlarmScheduler(
            alarms: { [store] in store.alarms },
            onFire: { alarm in
                print("agent: firing '\(alarm.label)'")
                guard let runner else {
                    NSLog("agent: no runner connection — skipping presentation")
                    return
                }
                Task {
                    let shown = await runner.present(alarm)
                    if !shown {
                        NSLog("agent: runner did not present the alarm")
                    }
                    fflush(stdout)
                }
            }
        )
        self.scheduler = scheduler
        loopTask = scheduler.run()

        // Reload the schedule whenever any process writes to the store.
        tokens.append(darwin.addObserver(for: .alarmsDidChange) { [weak self] in
            Task { @MainActor in self?.resync("alarms changed") }
        })

        // Re-check after wake so alarms missed inside the grace window still fire.
        NSWorkspace.shared.notificationCenter.addObserver(
            self,
            selector: #selector(didWake),
            name: NSWorkspace.didWakeNotification,
            object: nil
        )
    }

    func stop() {
        loopTask?.cancel()
        loopTask = nil
        runner?.invalidate()
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