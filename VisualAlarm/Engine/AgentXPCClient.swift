/**
 * File: AgentXPCClient.swift
 * Created: 2026-10-13
 */

#if os(macOS)
import Foundation

/// Thin async wrapper over the agent XPC service connection.
final class AgentXPCClient {
    private let connection: NSXPCConnection
    private let service: AlarmSchedulerServiceProtocol

    /// - Parameters:
    ///   - serviceName: Override for tests; defaults to the bundled agent.
    init(serviceName: String = XPCServiceName.agent) {
        connection = NSXPCConnection(serviceName: serviceName)
        connection.remoteObjectInterface = NSXPCInterface(
            with: AlarmSchedulerServiceProtocol.self
        )
        connection.resume()
        service = connection.remoteObjectProxyWithErrorHandler { error in
            NSLog("AgentXPCClient: \(error.localizedDescription)")
        } as! AlarmSchedulerServiceProtocol
    }

    func resyncScheduler() async {
        await withCheckedContinuation { (continuation: CheckedContinuation<Void, Never>) in
            service.resyncScheduler { continuation.resume() }
        }
    }

    func alarmCount() async -> Int {
        await withCheckedContinuation { (continuation: CheckedContinuation<Int, Never>) in
            service.alarmCount { continuation.resume(returning: $0) }
        }
    }

    func invalidate() {
        connection.invalidate()
    }
}
#endif