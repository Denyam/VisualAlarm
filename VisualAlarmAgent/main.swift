import AppKit
import Foundation

// VisualAlarmAgent — resident scheduler agent.
// Registered once via SMAppService from the main app; launchd keeps it alive
// across the login session. Watches the shared alarm store and launches
// VisualAlarmRunner when an alarm comes due (including shortly after wake).

let app = NSApplication.shared
app.setActivationPolicy(.accessory)

// Smoke-test hook: terminate gracefully after N seconds so automated checks
// can capture startup output.
private let smokeTestSeconds = ProcessInfo.processInfo.environment["VA_SMOKE_SECONDS"]
    .flatMap(Double.init)
    .map { Int($0) }

if let seconds = smokeTestSeconds {
    Task { @MainActor in
        try? await Task.sleep(for: .seconds(seconds))
        print("agent: VA_SMOKE auto-stop")
        NSApp.terminate(nil)
    }
}

// Top-level code runs on the main thread before the run loop starts, so the
// delegate must be installed synchronously here (see AGENTS.md gotchas).
let coordinator = MainActor.assumeIsolated {
    AgentCoordinator()
}
app.delegate = coordinator

app.run()
