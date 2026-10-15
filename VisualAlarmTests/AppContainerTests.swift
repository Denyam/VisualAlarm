import Foundation
import Testing

@testable import VisualAlarm

struct AppContainerTests {

    @Test func directoryLivesInApplicationSupport() {
        let path = AppContainer.directory.path

        // Sandbox or not, the alarm data sits in Application Support/VisualAlarm —
        // inside the app's container when sandboxed, in the real Application
        // Support for unsandboxed test hosts.
        #expect(path.hasSuffix("Application Support/VisualAlarm"))
        #expect(
            FileManager.default.fileExists(atPath: AppContainer.directory.path)
        )
    }

    @Test func alarmsFilenameIsStable() {
        // Other processes and older installs locate the file by name.
        #expect(AppContainer.alarmsFilename == "alarms.json")
    }
}
