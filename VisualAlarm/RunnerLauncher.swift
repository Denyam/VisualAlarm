/**
 * File: RunnerLauncher.swift
 * Created: 2026-08-23
 */

#if os(macOS)
import AppKit
import Foundation

/// Spawns the alarm window process for a due alarm and records what is
/// firing so the runner can present specifics.
protocol RunnerLaunching {
    @discardableResult
    func launch(firingAlarm alarm: Alarm) -> Bool
}

final class WorkspaceRunnerLauncher: RunnerLaunching {
    private let groupDirectory: URL?
    private let opener: (URL) -> Bool

    /// - Parameters:
    ///   - groupDirectory: Overrides the App Group container (tests).
    ///   - opener: Performs the actual open (tests inject a spy).
    init(
        groupDirectory: URL? = nil,
        opener: ((URL) -> Bool)? = nil
    ) {
        self.groupDirectory = groupDirectory
        self.opener = opener ?? { NSWorkspace.shared.open($0) }
    }

    func launch(firingAlarm alarm: Alarm) -> Bool {
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
        return opener(runnerURL)
    }
}
#endif
