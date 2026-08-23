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

        // Activation only sticks once the run loop is running; requesting it
        // before app.run() gets dropped, and without it the Stop button can't
        // receive keyboard focus.
        DispatchQueue.main.async {
            NSApp.activate(ignoringOtherApps: true)
            if let stopWindow = self.window {
                print(
                    "runner: window visible=\(stopWindow.window.isVisible) "
                        + "frame=\(stopWindow.window.frame)"
                )
            }
        }

        startEffects()
    }

    func applicationWillTerminate(_ notification: Notification) {
        stopEffects()
    }

    private func currentAlarmLabel() -> String {
        // The agent records exactly which alarm is ringing.
        if let request = FireRequest.read(), !request.label.isEmpty {
            return request.label
        }
        // Fallback (direct launches during development): first enabled alarm.
        if let alarm = AlarmStore.shared.alarms.first(where: \.isEnabled) {
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
    let window: NSWindow

    init(alarmLabel: String) {
        let size = NSSize(width: 320, height: 140)
        var contentRect = NSRect(origin: .zero, size: size)
        if let screen = NSScreen.main {
            contentRect.origin = NSPoint(
                x: screen.frame.midX - size.width / 2,
                y: screen.frame.midY - size.height / 2
            )
        }
        // A plain NSWindow, NOT an NSPanel: panels default to
        // hidesOnDeactivate = true and never become key while an accessory
        // app is inactive, which left the stop UI invisible.
        window = NSWindow(
            contentRect: contentRect,
            styleMask: [.titled, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )
        super.init()

        window.level = .screenSaver
        window.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        window.titleVisibility = .hidden
        window.standardWindowButton(.closeButton)?.isHidden = true
        window.standardWindowButton(.miniaturizeButton)?.isHidden = true
        window.standardWindowButton(.zoomButton)?.isHidden = true
        window.isMovableByWindowBackground = false
        window.delegate = self

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
        window.contentView?.addSubview(stack)
        NSLayoutConstraint.activate([
            stack.centerXAnchor.constraint(equalTo: window.contentView!.centerXAnchor),
            stack.centerYAnchor.constraint(equalTo: window.contentView!.centerYAnchor),
        ])
    }

    func show() {
        window.makeKeyAndOrderFront(nil)
        // Belt and braces for an accessory app that may not be active.
        window.orderFrontRegardless()
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
