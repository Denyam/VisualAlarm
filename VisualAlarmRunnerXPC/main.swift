/**
 * File: main.swift
 * Created: 2026-10-15
 *
 * Runner XPC service entry point — on-demand XPC service.
 */

import Foundation

let listener = NSXPCListener.service()
let delegate = RunnerService()
listener.delegate = delegate
listener.resume()
RunLoop.current.run()
