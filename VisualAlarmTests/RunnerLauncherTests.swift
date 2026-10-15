#if os(macOS)
import Foundation
import Testing

@testable import VisualAlarm

struct RunnerLauncherTests {

    @Test func launchForwardsAlarmToTheRunnerService() {
        var shown: [(id: UUID, label: String)] = []
        let launcher = XPCRunnerLauncher(show: { alarmID, label, reply in
            shown.append((alarmID, label))
            reply(true)
        })

        let alarm = Alarm(label: "Morning run", hour: 6, minute: 30)
        launcher.launch(firingAlarm: alarm)

        // The alarm ID and label cross the XPC boundary directly now —
        // no fire-request file, no NSWorkspace app launch.
        #expect(shown.count == 1)
        #expect(shown[0].id == alarm.id)
        #expect(shown[0].label == "Morning run")
    }

    @Test func launchKeepsReachingTheRunnerAfterAFailedShow() {
        var attempts = 0
        let launcher = XPCRunnerLauncher(show: { _, _, reply in
            attempts += 1
            reply(false)
        })

        let alarm = Alarm(label: "Backup", hour: 7, minute: 0)
        launcher.launch(firingAlarm: alarm)
        launcher.launch(firingAlarm: alarm)

        #expect(attempts == 2)
    }
}
#endif
