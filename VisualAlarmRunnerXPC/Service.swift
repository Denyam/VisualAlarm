/**
 * File: Service.swift
 * Created: 2026-10-14
 *
 * Runner XPC Service — LSUIElement alarm window process.
 * Shows the stop window, plays looping sound, and flickers display brightness.
 */

import Foundation
import AppKit

final class RunnerService: NSObject, AlarmRunnerProtocol, NSXPCListenerDelegate {
    private var coordinator: AlarmCoordinator?

    // MARK: - NSXPCListenerDelegate

    func listener(_ listener: NSXPCListener, shouldAcceptNewConnection connection: NSXPCConnection) -> Bool {
        connection.exportedInterface = NSXPCInterface(with: AlarmRunnerProtocol.self)
        connection.exportedObject = self
        connection.resume()
        return true
    }

    // MARK: - AlarmRunnerProtocol

    func showAlarmWindow(alarmID: String, label: String, reply: @escaping (Bool) -> Void) {
        DispatchQueue.main.async {
            if self.coordinator == nil {
                self.coordinator = AlarmCoordinator()
            }
            self.coordinator?.showAlarm(alarmID: alarmID, label: label)
            reply(true)
        }
    }

    func closeAlarmWindow(reply: @escaping (Bool) -> Void) {
        DispatchQueue.main.async {
            self.coordinator?.closeAlarm()
            reply(true)
        }
    }
}