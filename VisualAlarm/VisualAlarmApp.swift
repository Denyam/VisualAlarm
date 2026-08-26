//
//  VisualAlarmApp.swift
//  VisualAlarm
//
//  Created by Denis on 14.08.2026.
//

import SwiftUI

@main
struct VisualAlarmApp: App {
    var body: some Scene {
        WindowGroup {
            ContentView()
                #if os(macOS)
                .task { await Self.runMaintenanceHooksIfNeeded() }
                #endif
        }
    }

    #if os(macOS)
    /// Headless maintenance hooks for scripts/tests:
    /// `VA_AGENT_HOOK=register|unregister|status` performs the action, then quits.
    /// `VA_SMOKE_SECONDS=N` loads the store and terminates after N seconds.
    @MainActor
    private static func runMaintenanceHooksIfNeeded() async {
        if let seconds = ProcessInfo.processInfo.environment["VA_SMOKE_SECONDS"]
            .flatMap(Double.init).map({ Int($0) }) {
            let store = AlarmStore.shared
            print("app: loaded \(store.alarms.count) alarm(s) from \(AppGroup.directory.path)")
            fflush(stdout)
            try? await Task.sleep(for: .seconds(seconds))
            NSApp.terminate(nil)
            return
        }

        guard let hook = ProcessInfo.processInfo.environment["VA_AGENT_HOOK"] else {
            return
        }

        let registrar = SMAppServiceRegistrar()
        switch hook {
        case "register":
            do { try registrar.register() } catch {
                NSLog("hook register failed: \(error.localizedDescription)")
            }
        case "unregister":
            do { try registrar.unregister() } catch {
                NSLog("hook unregister failed: \(error.localizedDescription)")
            }
        default:
            break
        }

        print("VA_HOOK result status=\(registrar.status)")
        fflush(stdout)
        await Task.yield()
        NSApp.terminate(nil)
    }
    #endif
}
