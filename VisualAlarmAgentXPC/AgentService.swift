/**
 * File: Service.swift
 * Created: 2026-10-14
 *
 * Agent service — scheduler + alarm storage for the VisualAlarm agent.
 * Runs independently of the main app so alarms fire even when app is closed.
 */

import Foundation
import AppKit

@MainActor
final class AgentService: NSObject, AlarmSchedulerProtocol, NSXPCListenerDelegate {

    /// How this process was launched.
    enum Mode {
        /// launchd runs the binary as a login item (`BundleProgram`): owns
        /// the fire loop. No XPC listener — service listeners only work in
        /// an xpcproxy launch context.
        case resident
        /// xpcproxy spawned it on demand for the app's connection: serves
        /// RPCs and owns alarm persistence; the resident instance re-reads
        /// the shared store whenever `.alarmsDidChange` fires.
        case service
    }

    private let mode: Mode
    // AlarmStore defaults to AppContainer.directory — the current process's
    // Application Support, i.e. inside the agent's own sandbox container.
    private let store = AlarmStore.shared
    // Built lazily after super.init(): the onFire closure captures `self`.
    private lazy var scheduler: AlarmScheduler = AlarmScheduler(
        alarms: { [store] in store.alarms },
        onFire: { [weak self] alarm in
            self?.launchRunner(for: alarm)
        }
    )
    private var loopTask: Task<Void, Never>?
    private let darwin = DarwinNotificationCenter.shared
    private var tokens: [DarwinObservationToken] = []

    init(mode: Mode) {
        self.mode = mode
        super.init()
        if mode == .resident {
            print("agent: resident scheduler with \(store.alarms.count) alarm(s)")
            // Drive the fire loop; without it the scheduler never evaluates
            // alarms. The on-demand instance must NOT run it — two loops
            // would fire every alarm twice.
            loopTask = scheduler.run()
            setupObservers()
        }
    }

    // MARK: - NSXPCListenerDelegate

    // XPC delivers delegate callbacks and exported-method calls off the main
    // thread, so these entry points stay nonisolated and hop to the main actor.
    nonisolated func listener(
        _ listener: NSXPCListener,
        shouldAcceptNewConnection connection: NSXPCConnection
    ) -> Bool {
        connection.exportedInterface = NSXPCInterface(with: AlarmSchedulerProtocol.self)
        connection.exportedObject = self
        connection.resume()
        return true
    }

    // MARK: - AlarmSchedulerProtocol

    nonisolated func scheduleAlarm(_ alarmData: Data, reply: @escaping (Bool) -> Void) {
        Task { @MainActor in
            guard let alarm = XPCRepresentation.decodeAlarm(alarmData) else {
                reply(false)
                return
            }
            store.upsert(alarm)
            reply(true)
        }
    }

    nonisolated func cancelAlarm(id: String, reply: @escaping (Bool) -> Void) {
        Task { @MainActor in
            guard let uuid = UUID(uuidString: id) else {
                reply(false)
                return
            }
            store.delete(id: uuid)
            reply(true)
        }
    }

    nonisolated func getPendingAlarms(reply: @escaping (Data?) -> Void) {
        Task { @MainActor in
            reply(XPCRepresentation.encode(store.alarms))
        }
    }

    nonisolated func resync(reply: @escaping () -> Void) {
        Task { @MainActor in
            if mode == .resident {
                scheduler.resync()
            } else {
                // On-demand instance: hand off to the resident scheduler,
                // which re-reads the shared store on this signal.
                darwin.post(.alarmsDidChange)
            }
            reply()
        }
    }

    // MARK: - Private

    private func setupObservers() {
        // The app's edits reach this instance through the store: the
        // on-demand instance persists a sync and AlarmStore posts the
        // Darwin signal — reload the schedule context when it arrives.
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

    @objc private func didWake() {
        resync("wake from sleep")
    }

    private func resync(_ reason: String) {
        print("agent: resync (\(reason))")
        let count = store.load().count
        print("agent: store now has \(count) alarm(s)")
        scheduler.resync()
    }

    private func launchRunner(for alarm: Alarm) {
        print("agent: firing '\(alarm.label)'")
        let connection = NSXPCConnection(serviceName: "co.denis.VisualAlarm.runner.xpc")
        connection.remoteObjectInterface = NSXPCInterface(with: AlarmRunnerProtocol.self)
        connection.resume()

        let proxy = connection.remoteObjectProxyWithErrorHandler { error in
            print("agent: runner XPC error: \(error)")
        } as! AlarmRunnerProtocol

        proxy.showAlarmWindow(alarmID: alarm.id.uuidString, label: alarm.label) { success in
            print("agent: runner show result: \(success)")
            connection.invalidate()
        }
    }
}