/**
 * File: RunnerXPCClient.swift
 * Created: 2026-10-13
 */

#if os(macOS)
import Foundation

/// Thin async wrapper over the runner XPC service connection.
final class RunnerXPCClient {
    private let connection: NSXPCConnection
    private let service: AlarmRunnerServiceProtocol

    /// - Parameters:
    ///   - serviceName: Override for tests; defaults to the bundled runner.
    init(serviceName: String = XPCServiceName.runner) {
        connection = NSXPCConnection(serviceName: serviceName)
        connection.remoteObjectInterface = NSXPCInterface(
            with: AlarmRunnerServiceProtocol.self
        )
        connection.resume()
        service = connection.remoteObjectProxyWithErrorHandler { error in
            NSLog("RunnerXPCClient: \(error.localizedDescription)")
        } as! AlarmRunnerServiceProtocol
    }

    func present(_ alarm: Alarm) async -> Bool {
        guard let payload = try? XPCAlarm(alarm).encoded() else { return false }
        return await withCheckedContinuation { (continuation: CheckedContinuation<Bool, Never>) in
            service.presentAlarm(payload) { continuation.resume(returning: $0) }
        }
    }

    func dismiss() async -> Bool {
        await withCheckedContinuation { (continuation: CheckedContinuation<Bool, Never>) in
            service.dismissAlarm { continuation.resume(returning: $0) }
        }
    }

    func invalidate() {
        connection.invalidate()
    }
}
#endif