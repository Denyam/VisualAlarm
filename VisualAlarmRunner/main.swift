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
    exit(0)
}

let app = NSApplication.shared
app.setActivationPolicy(.accessory)

Task { @MainActor in
    let coordinator = AlarmCoordinator()
    app.delegate = coordinator
} // Note: app.run() will process this Task

if let seconds = smokeTestSeconds {
    Task { @MainActor in
        try? await Task.sleep(for: .seconds(seconds))
        print("VA_SMOKE: auto-stopping after \(seconds)s")
        NSApp.terminate(nil)
    }
}

app.activate(ignoringOtherApps: true)
app.run()

// MARK: - Alarm coordinator

@MainActor
final class AlarmCoordinator: NSObject, NSApplicationDelegate {
    private var window: StopWindow?
    private var sound: LoopingSound?
    private var effectTask: Task<Void, Never>?

    private let brightness = MacBrightnessController()
    private let flicker = FlickerEffectController(interval: .milliseconds(500))

    func applicationDidFinishLaunching(_ notification: Notification) {
        let alarm = currentAlarmLabel()
        window = StopWindow(alarmLabel: alarm)
        window?.show()

        startEffects()
    }

    func applicationWillTerminate(_ notification: Notification) {
        stopEffects()
    }

    private func currentAlarmLabel() -> String {
        let store = AlarmStore.shared
        if let alarm = store.alarms.first(where: \.isEnabled) {
            return String(format: "%02d:%02d %@", alarm.hour, alarm.minute, alarm.label)
                .trimmingCharacters(in: .whitespaces)
        }
        return "Visual alarm"
    }

    private func startEffects() {
        sound = LoopingSound(named: "Funk")
        sound?.play()

        brightness.storeCurrentLevels()
        effectTask = flicker.start(
            clock: ContinuousClock(),
            onPhase: { [brightness] in brightness.setAllDisplays(to: 1.0) },
            offPhase: { [brightness] in brightness.setAllDisplays(to: 0.0) },
            restore: { [brightness] in brightness.restoreStoredLevels() }
        )
    }

    private func stopEffects() {
        sound?.stop()
        sound = nil
        effectTask?.cancel()
        effectTask = nil
        // The task's own restore runs asynchronously and could lose the race
        // against process exit, so restore synchronously here as well
        // (a second restore is a no-op — originals are released after use).
        brightness.restoreStoredLevels()
    }
}

// MARK: - Stop window

@MainActor
final class StopWindow: NSObject, NSWindowDelegate {
    private let panel: NSPanel
    private var sound: LoopingSound?

    init(alarmLabel: String) {
        let size = NSSize(width: 320, height: 140)
        if let screen = NSScreen.main {
            let origin = NSPoint(
                x: screen.frame.midX - size.width / 2,
                y: screen.frame.midY - size.height / 2
            )
            panel = NSPanel(
                contentRect: NSRect(origin: origin, size: size),
                styleMask: [.titled, .fullSizeContentView],
                backing: .buffered,
                defer: false
            )
        } else {
            panel = NSPanel(
                contentRect: NSRect(origin: .zero, size: size),
                styleMask: [.titled, .fullSizeContentView],
                backing: .buffered,
                defer: false
            )
        }
        super.init()

        panel.level = .screenSaver
        panel.isFloatingPanel = true
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        panel.titleVisibility = .hidden
        panel.standardWindowButton(.closeButton)?.isHidden = true
        panel.isMovableByWindowBackground = false

        let label = NSTextField(labelWithString: "⏰ \(alarmLabel)")
        label.font = .boldSystemFont(ofSize: 20)
        label.alignment = .center

        let button = NSButton(
            title: "Stop",
            target: self,
            action: #selector(stopClicked)
        )
        button.bezelStyle = .rounded
        button.keyEquivalent = "\r"
        button.controlSize = .large
        button.font = .boldSystemFont(ofSize: 16)

        let stack = NSStackView(views: [label, button])
        stack.orientation = .vertical
        stack.spacing = 24
        stack.translatesAutoresizingMaskIntoConstraints = false
        panel.contentView?.addSubview(stack)
        NSLayoutConstraint.activate([
            stack.centerXAnchor.constraint(equalTo: panel.contentView!.centerXAnchor),
            stack.centerYAnchor.constraint(equalTo: panel.contentView!.centerYAnchor),
        ])
    }

    func show() {
        panel.makeKeyAndOrderFront(nil)
    }

    @objc private func stopClicked() {
        NSApp.terminate(nil)
    }
}

// MARK: - Looping system sound

final class LoopingSound: NSObject, NSSoundDelegate {
    private let sound: NSSound?
    private var shouldLoop = true

    init(named name: String) {
        sound = NSSound(named: name)
        super.init()
        sound?.delegate = self
    }

    func play() {
        shouldLoop = true
        _ = sound?.play()
    }

    func stop() {
        shouldLoop = false
        sound?.stop()
    }

    func sound(_ sound: NSSound, didFinishPlaying finished: Bool) {
        guard shouldLoop else { return }
        _ = sound.play()
    }
}
