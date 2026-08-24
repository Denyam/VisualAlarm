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
    @MainActor
    private static func runMaintenanceHooksIfNeeded() async {
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
