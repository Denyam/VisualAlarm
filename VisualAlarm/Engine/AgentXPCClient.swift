/**
 * File: AgentXPCClient.swift
 * Created: 2026-10-14
 *
 * XPC client for communicating with the agent XPC service.
 */

#if os(macOS)
import Foundation

@MainActor
final class AgentXPCClient {
    private let connection: NSXPCConnection
    private let proxy: AlarmSchedulerProtocol

    init() {
        connection = NSXPCConnection(serviceName: "co.denis.VisualAlarm.agent.xpc")
        connection.remoteObjectInterface = NSXPCInterface(with: AlarmSchedulerProtocol.self)
        connection.resume()
        proxy = connection.remoteObjectProxyWithErrorHandler { error in
            print("AgentXPCClient error: \(error)")
        } as! AlarmSchedulerProtocol
    }

    func schedule(_ alarm: Alarm) async -> Bool {
        guard let data = XPCRepresentation.encode(alarm) else { return false }
        return await withCheckedContinuation { continuation in
            proxy.scheduleAlarm(data) { success in
                continuation.resume(returning: success)
            }
        }
    }

    func cancel(id: UUID) async -> Bool {
        await withCheckedContinuation { continuation in
            proxy.cancelAlarm(id: id.uuidString) { success in
                continuation.resume(returning: success)
            }
        }
    }

    func getPendingAlarms() async -> [Alarm] {
        await withCheckedContinuation { continuation in
            proxy.getPendingAlarms { data in
                let alarms = data.flatMap { XPCRepresentation.decodeAlarms($0) } ?? []
                continuation.resume(returning: alarms)
            }
        }
    }

    func resync() async {
        await withCheckedContinuation { continuation in
            proxy.resync {
                continuation.resume()
            }
        }
    }

    func invalidate() {
        connection.invalidate()
    }
}
#endif