//
// DeploymentTargetTestMacApp
//

import AppKit
internal import SwiftUI

@NSApplicationMain
class AppDelegate: NSObject, NSApplicationDelegate {
    static private let width = 800.0
    static private let height = 600.0

    var window: NSWindow!

    func applicationDidFinishLaunching(_ aNotification: Notification) {
        window = NSWindow(
            contentRect: NSMakeRect(0, 0, Self.width, Self.height),
            styleMask: [.titled, .closable, .miniaturizable, .resizable],
            backing: .buffered,
            defer: false
        )
        
        window.center()
        window.title = "My App"

        let contentView = ContentView().frame(width: Self.width, height: Self.height)
        let hostingController = NSHostingController(rootView: contentView)
        
        window.contentView = hostingController.view
        window.makeKeyAndOrderFront(self)
        
        NSApplication.shared.activate(ignoringOtherApps: false)
    }

    func applicationWillTerminate(_ aNotification: Notification) {
        // Cleanup code if necessary
    }
}
