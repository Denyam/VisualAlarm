/**
 * File: main.swift
 * Created: 2026-10-15
 *
 * Agent XPC service entry point — launchd calls this, keeps the process alive.
 */

import Foundation

// Top-level main.swift code runs on the main thread, but is not MainActor-
// isolated to the compiler, so wrap the @MainActor service construction.
let listener = NSXPCListener.service()
let delegate = MainActor.assumeIsolated { AgentService() }
listener.delegate = delegate
listener.resume()
RunLoop.current.run()
