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
        print("runner: didFinishLaunching")
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
        let soundLoaded = sound?.isAvailable == true
        print("runner: sound loaded=\(soundLoaded)")
        sound?.play()

        brightness.storeCurrentLevels()
        print(
            "runner: brightness supported=\(brightness.isSupported) "
                + "displays=\(brightness.displayCount)"
        )
        effectTask = flicker.start(
            clock: ContinuousClock(),
            onPhase: { [brightness] in
                if !brightness.setAllDisplays(to: 1.0) {
                    print("runner: set max FAILED")
                }
            },
            offPhase: { [brightness] in
                if !brightness.setAllDisplays(to: 0.0) {
                    print("runner: set min FAILED")
                }
            },
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

    /// Whether a system sound with the given name was found.
    var isAvailable: Bool { sound != nil }

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
