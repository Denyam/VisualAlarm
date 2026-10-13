/**
 * File: main.swift
 * Created: 2026-10-13
 *
 * Entry point for the runner XPC service. Started on demand by whoever
 * presents an alarm (the agent, or the app) and torn down when that
 * connection closes.
 */

import AppKit
import Foundation

let application = NSApplication.shared
application.setActivationPolicy(.accessory)

// Created synchronously on the main thread before the run loop starts.
let presenter = MainActor.assumeIsolated { AlarmPresenter() }

/// Bridges XPC messages onto the main actor.
final class RunnerServiceAdapter: NSObject, AlarmRunnerServiceProtocol, NSXPCListenerDelegate {
    private let presenter: AlarmPresenter

    init(presenter: AlarmPresenter) {
        self.presenter = presenter
    }

    // MARK: NSXPCListenerDelegate

    func listener(
        _ listener: NSXPCListener,
        shouldAcceptNewConnection connection: NSXPCConnection
    ) -> Bool {
        connection.exportedInterface = NSXPCInterface(
            with: AlarmRunnerServiceProtocol.self
        )
        connection.exportedObject = self
        connection.resume()
        return true
    }

    // MARK: AlarmRunnerServiceProtocol

    func presentAlarm(_ payload: Data, reply: @escaping (Bool) -> Void) {
        guard let wire = try? XPCAlarm.decode(payload),
              let alarm = wire.alarm
        else {
            NSLog("runner: could not decode alarm payload")
            reply(false)
            return
        }
        Task { @MainActor in
            self.presenter.present(alarm: alarm)
            reply(true)
        }
    }

    func dismissAlarm(reply: @escaping (Bool) -> Void) {
        Task { @MainActor in
            self.presenter.dismiss()
            reply(true)
        }
    }
}

let listener = NSXPCListener.service()
let adapter = RunnerServiceAdapter(presenter: presenter)
listener.delegate = adapter
listener.resume()

// Blocks until the last XPC connection goes away, then the service exits.
application.run()