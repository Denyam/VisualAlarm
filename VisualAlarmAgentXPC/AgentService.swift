/**
 * File: Service.swift
 * Created: 2026-10-14
 *
 * Agent XPC Service — resident scheduler launched by launchd.
 * Runs independently of the main app so alarms fire even when app is closed.
 */

import Foundation
import AppKit

final class AgentService: NSObject, AlarmSchedulerProtocol, NSXPCListenerDelegate {
    private let store = AlarmStore.shared
    private let scheduler: AlarmScheduler
    private var loopTask: Task<Void, Never>?
    private let darwin = DarwinNotificationCenter.shared
    private var tokens: [DarwinObservationToken] = []

    override init() {
        self.scheduler = AlarmScheduler(
            alarms: { [store] in store.alarms },
            onFire: { [weak self] alarm in
                self?.launchRunner(for: alarm)
            }
        )
        super.init()
        setupObservers()
    }

    // MARK: - NSXPCListenerDelegate

    func listener(_ listener: NSXPCListener, shouldAcceptNewConnection connection: NSXPCConnection) -> Bool {
        connection.exportedInterface = NSXPCInterface(with: AlarmSchedulerProtocol.self)
        connection.exportedObject = self
        connection.resume()
        return true
    }

    // MARK: - AlarmSchedulerProtocol

    func scheduleAlarm(_ alarmData: Data, reply: @escaping (Bool) -> Void) {
        guard let alarm = XPCRepresentation.decodeAlarm(alarmData) else {
            reply(false)
            return
        }
        store.upsert(alarm)
        reply(true)
    }

    func cancelAlarm(id: String, reply: @escaping (Bool) -> Void) {
        guard let uuid = UUID(uuidString: id) else {
            reply(false)
            return
        }
        store.delete(id: uuid)
        reply(true)
    }

    func getPendingAlarms(reply: @escaping (Data?) -> Void) {
        let data = XPCRepresentation.encode(store.alarms)
        reply(data)
    }

    func resync(reply: @escaping () -> Void) {
        scheduler.resync()
        reply()
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

// Entry point — launchd calls this, keeps process alive
let listener = NSXPCListener.service()
let delegate = AgentService()
listener.delegate = delegate
listener.resume()
RunLoop.current.run()
