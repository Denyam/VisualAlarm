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

// MARK: - Agent coordinator

@MainActor
final class AgentCoordinator: NSObject, NSApplicationDelegate {
    private let store = AlarmStore.shared
    private let darwin = DarwinNotificationCenter.shared
    private let launcher: any RunnerLaunching = WorkspaceRunnerLauncher()
    private var scheduler: AlarmScheduler?
    private var loopTask: Task<Void, Never>?
    private var tokens: [DarwinObservationToken] = []

    func applicationDidFinishLaunching(_ notification: Notification) {
        print("agent: started with \(store.alarms.count) alarm(s)")

        let scheduler = AlarmScheduler(
            alarms: { [store] in store.alarms },
            onFire: { [launcher] alarm in
                print("agent: firing '\(alarm.label)'")
                launcher.launch(firingAlarm: alarm)
            }
        )
        self.scheduler = scheduler
        loopTask = scheduler.run()

        // Reload schedule context when alarms change anywhere.
        tokens.append(darwin.addObserver(for: .alarmsDidChange) { [weak self] in
            Task { @MainActor in self?.resync("alarms changed") }
        })

        // Re-check immediately after the Mac wakes so missed alarms inside
        // the grace window still fire.
        NSWorkspace.shared.notificationCenter.addObserver(
            self,
            selector: #selector(didWake),
            name: NSWorkspace.didWakeNotification,
            object: nil
        )
    }

    func applicationWillTerminate(_ notification: Notification) {
        loopTask?.cancel()
        loopTask = nil
    }

    @objc private func didWake() {
        resync("wake from sleep")
    }

    private func resync(_ reason: String) {
        print("agent: resync (\(reason))")
        scheduler?.resync()
    }
}
