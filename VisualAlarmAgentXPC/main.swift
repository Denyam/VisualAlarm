/**
 * File: main.swift
 * Created: 2026-10-13
 *
 * Entry point for the agent XPC service. launchd starts this binary at login
 * (RunAtLoad + KeepAlive) via the plist in Contents/Library/LaunchAgents, so
 * the scheduler runs for the whole login session even when the main app is
 * closed. The XPC listener is still served so the app can poke the scheduler.
 */

import AppKit
import Foundation

let application = NSApplication.shared
application.setActivationPolicy(.accessory)

// Top-level code runs on the main thread before the run loop starts, so any
// MainActor work has to be set up synchronously here (see AGENTS.md gotchas).
let agent = MainActor.assumeIsolated { AgentService() }

final class AgentConnectionHandler: NSObject, NSXPCListenerDelegate {
    private let agent: AgentService

    init(agent: AgentService) {
        self.agent = agent
    }

    func listener(
        _ listener: NSXPCListener,
        shouldAcceptNewConnection connection: NSXPCConnection
    ) -> Bool {
        connection.exportedInterface = NSXPCInterface(
            with: AlarmSchedulerServiceProtocol.self
        )
        connection.exportedObject = agent
        connection.resume()
        return true
    }
}

let listener = NSXPCListener.service()
// NSXPCListener.delegate is weak, so the handler must outlive the listener or
// every incoming connection gets rejected. A top-level `let` is a global and
// is retained for the life of the process.
let connectionHandler = AgentConnectionHandler(agent: agent)
listener.delegate = connectionHandler
listener.resume()

MainActor.assumeIsolated { agent.start() }

// Blocks forever; launchd owns the process lifetime from here.
application.run()