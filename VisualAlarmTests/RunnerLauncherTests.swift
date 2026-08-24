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
            opener: { openedURL = $0 }
        )

        let alarm = Alarm(label: "Morning run", hour: 6, minute: 30)
        launcher.launch(firingAlarm: alarm)

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
            opener: { _ in } // simulate an open that never succeeds
        )

        let alarm = Alarm(label: "Backup", hour: 7, minute: 0)
        launcher.launch(firingAlarm: alarm)

        #expect(FireRequest.read(directory: directory)?.alarmID == alarm.id)
    }
}
