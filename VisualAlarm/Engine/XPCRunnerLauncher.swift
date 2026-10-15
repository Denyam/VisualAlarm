/**
 * File: XPCRunnerLauncher.swift
 * Created: 2026-10-15
 *
 * Presents a firing alarm through the runner XPC service. Replaces the old
 * NSWorkspace launch of VisualAlarmRunner.app: the alarm ID and label cross
 * the XPC boundary in `showAlarmWindow(alarmID:label:reply:)`, so no
 * fire-request file has to be shared between processes anymore.
 */

#if os(macOS)
import Foundation

final class XPCRunnerLauncher: RunnerLaunching {
    /// Performs the runner round trip; `reply` carries the service's verdict.
    typealias Show = (UUID, String, @escaping (Bool) -> Void) -> Void

    private let show: Show

    /// - Parameter show: Overrides the XPC round trip (tests inject a spy).
    init(show: Show? = nil) {
        self.show = show ?? { alarmID, label, reply in
            Task { @MainActor in
                reply(
                    await RunnerXPCClient.shared.showAlarm(
                        id: alarmID,
                        label: label
                    )
                )
            }
        }
    }

    func launch(firingAlarm alarm: Alarm) {
        show(alarm.id, alarm.label) { success in
            if success {
                NSLog("runner: XPC showed alarm '\(alarm.label)'")
            } else {
                NSLog("runner: XPC show FAILED for '\(alarm.label)'")
            }
        }
    }
}
#endif
