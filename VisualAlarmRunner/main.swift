import AppKit
import Foundation

// VisualAlarmRunner — LSUIElement alarm process.
// Plays a looping system sound and flickers display brightness between min
// and max until the user presses Stop (or a smoke-test timeout fires).

private let smokeTestSeconds = ProcessInfo.processInfo.environment["VA_SMOKE_SECONDS"]
    .flatMap(Double.init)
    .map { Int($0) }

// MARK: - Single instance guard

private let bundleIdentifier =
    Bundle.main.bundleIdentifier ?? "co.denis.VisualAlarm.runner"

private let otherInstances = NSRunningApplication
    .runningApplications(withBundleIdentifier: bundleIdentifier)
    .filter { $0 != NSRunningApplication.current }

if !otherInstances.isEmpty {
    print("runner: another instance is already running — exiting")
    exit(0)
}

let app = NSApplication.shared
app.setActivationPolicy(.accessory)

// Top-level code runs on the main thread before the run loop starts, so it is
// safe (and required — applicationDidFinishLaunching fires inside app.run())
// to install the delegate synchronously on the MainActor here. Deferring via
// Task { @MainActor } misses the launch notification entirely.
let coordinator = MainActor.assumeIsolated {
    AlarmCoordinator()
}
app.delegate = coordinator

if let seconds = smokeTestSeconds {
    Task { @MainActor in
        try? await Task.sleep(for: .seconds(seconds))
        print("VA_SMOKE: auto-stopping after \(seconds)s")
        NSApp.terminate(nil)
    }
}

app.run()
