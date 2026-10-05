//
//  MaintenanceHooks.swift
//  VisualAlarm
//

import AppKit
import Foundation

/// Headless maintenance hooks for scripts/tests (macOS only):
/// `VA_AGENT_HOOK=register|unregister|status` performs the action, then quits.
/// `VA_SMOKE_SECONDS=N` loads the store and terminates after N seconds.
///
/// Runs from `applicationDidFinishLaunching` (both the SwiftUI and the
/// macOS 10.15 AppKit entry paths) — the former `.task` hook needed macOS 12.
enum MaintenanceHooks {
    @MainActor
    static func runIfNeeded() async {
        if let seconds = ProcessInfo.processInfo.environment["VA_SMOKE_SECONDS"]
            .flatMap(Double.init).map({ Int($0) }) {
            let store = AlarmStore.shared
            print("app: loaded \(store.alarms.count) alarm(s) from \(AppGroup.directory.path)")
            fflush(stdout)
            try? await Task.sleep(seconds: TimeInterval(seconds))
            NSApp.terminate(nil)
            return
        }

        guard let hook = ProcessInfo.processInfo.environment["VA_AGENT_HOOK"] else {
            return
        }

        let registrar = AgentRegistrationFactory.make()
        switch hook {
        case "register":
            _ = await registrar.setEnabled(true)
        case "unregister":
            _ = await registrar.setEnabled(false)
        default:
            break
        }

        print("VA_HOOK result status=\(await registrar.currentStatus())")
        fflush(stdout)
        await Task.yield()
        NSApp.terminate(nil)
    }
}
