/**
 * File: RunnerLauncher.swift
 * Created: 2026-08-23
 */

#if os(macOS)
import AppKit
import Foundation

final class WorkspaceRunnerLauncher: RunnerLaunching {
    private let groupDirectory: URL?
    private let opener: (URL) -> Void

    /// - Parameters:
    ///   - groupDirectory: Overrides the App Group container (tests).
    ///   - opener: Performs the actual open (tests inject a spy).
    init(
        groupDirectory: URL? = nil,
        opener: ((URL) -> Void)? = nil
    ) {
        self.groupDirectory = groupDirectory
        self.opener = opener ?? { url in
            NSWorkspace.shared.openApplication(
                at: url,
                configuration: NSWorkspace.OpenConfiguration()
            ) { _, error in
                if let error {
                    NSLog("agent: open failed — \(error)")
                } else {
                    NSLog("agent: opened runner")
                }
            }
        }
    }

    func launch(firingAlarm alarm: Alarm) {
        let request = FireRequest(
            alarmID: alarm.id,
            label: alarm.label,
            firedAt: Date()
        )
        do {
            try FireRequest.write(request, directory: groupDirectory)
        } catch {
            NSLog("agent: writing fire request failed: \(error.localizedDescription)")
        }

        let runnerURL = Bundle.main.bundleURL
            .deletingLastPathComponent()
            .appendingPathComponent("VisualAlarmRunner.app")
        opener(runnerURL)
    }
}
#endif
