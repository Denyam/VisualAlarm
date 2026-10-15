/**
 * File: RunnerXPCClient.swift
 * Created: 2026-10-14
 *
 * XPC client for communicating with the runner XPC service.
 */

#if os(macOS)
import Foundation

@MainActor
final class RunnerXPCClient {
    private let connection: NSXPCConnection
    private let proxy: AlarmRunnerProtocol

    init() {
        connection = NSXPCConnection(serviceName: "co.denis.VisualAlarm.runner.xpc")
        connection.remoteObjectInterface = NSXPCInterface(with: AlarmRunnerProtocol.self)
        connection.resume()
        proxy = connection.remoteObjectProxyWithErrorHandler { error in
            print("RunnerXPCClient error: \(error)")
        } as! AlarmRunnerProtocol
    }

    func showAlarm(id: UUID, label: String) async -> Bool {
        await withCheckedContinuation { continuation in
            proxy.showAlarmWindow(alarmID: id.uuidString, label: label) { success in
                continuation.resume(returning: success)
            }
        }
    }

    func closeAlarm() async -> Bool {
        await withCheckedContinuation { continuation in
            proxy.closeAlarmWindow { success in
                continuation.resume(returning: success)
            }
        }
    }

    func invalidate() {
        connection.invalidate()
    }
}
#endif