/**
 * File: main.swift
 * Created: 2026-10-15
 *
 * Agent XPC service entry point. Two launch contexts:
 *
 * - xpcproxy (the app connects by name): a real XPC service — install the
 *   service listener. `NSXPCListener.service()` aborts anywhere else
 *   ("An XPC Service cannot be run directly").
 * - launchd (`SMAppService` BundleProgram, `VA_AGENT_RESIDENT=1` set in the
 *   job's EnvironmentVariables): the resident scheduler — no listener, just
 *   keep the run loop (and the fire loop inside AgentService) alive.
 */

import Foundation

let isResident = ProcessInfo.processInfo.environment["VA_AGENT_RESIDENT"] != nil

// Top-level main.swift code runs on the main thread, but is not MainActor-
// isolated to the compiler, so wrap the @MainActor service construction.
// The top-level `let` also keeps the service alive: NSXPCListener keeps a
// weak reference to its delegate.
let service = MainActor.assumeIsolated {
    AgentService(mode: isResident ? .resident : .service)
}

if isResident {
    print("agent: resident mode (launchd)")
} else {
    print("agent: on-demand XPC service mode")
    let listener = NSXPCListener.service()
    listener.delegate = service
    listener.resume()
}

RunLoop.current.run()
