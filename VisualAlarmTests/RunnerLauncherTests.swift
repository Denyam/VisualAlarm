/**
 * File: RunnerLauncherTests.swift
 * Created: 2026-08-23
 */

import Foundation
import Testing

@testable import VisualAlarm

struct RunnerLauncherTests {

    private func temporaryDirectory() throws -> URL {
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(
            at: url,
            withIntermediateDirectories: true
        )
        return url
    }

    @Test func launchRecordsFireRequestAndOpensRunner() throws {
        let directory = try temporaryDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }

        var openedURL: URL?
        let launcher = WorkspaceRunnerLauncher(
            groupDirectory: directory,
            opener: { openedURL = $0; return true }
        )

        let alarm = Alarm(label: "Morning run", hour: 6, minute: 30)
        let result = launcher.launch(firingAlarm: alarm)

        #expect(result == true)
        #expect(openedURL?.lastPathComponent == "VisualAlarmRunner.app")

        let request = FireRequest.read(directory: directory)
        #expect(request?.alarmID == alarm.id)
        #expect(request?.label == "Morning run")
    }

    @Test func launchStillRecordsRequestWhenOpeningFails() throws {
        let directory = try temporaryDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }

        let launcher = WorkspaceRunnerLauncher(
            groupDirectory: directory,
            opener: { _ in false }
        )

        let alarm = Alarm(label: "Backup", hour: 7, minute: 0)
        let result = launcher.launch(firingAlarm: alarm)

        #expect(result == false)
        #expect(FireRequest.read(directory: directory)?.alarmID == alarm.id)
    }
}
