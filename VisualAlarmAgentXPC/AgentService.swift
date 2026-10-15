/**
 * File: Service.swift
 * Created: 2026-10-14
 *
 * Agent XPC Service — resident scheduler launched by launchd.
 * Runs independently of the main app so alarms fire even when app is closed.
 */

import Foundation
import AppKit

@MainActor
final class AgentService: NSObject, AlarmSchedulerProtocol, NSXPCListenerDelegate {
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

    override init() {
        super.init()
        // Drive the fire loop; without it the scheduler never evaluates alarms.
        loopTask = scheduler.run()
        setupObservers()
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
            scheduler.resync()
            reply()
        }
    }

    // MARK: - Private

    private func setupObservers() {
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