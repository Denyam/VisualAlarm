//
//  AppDelegate.swift
//  VisualAlarm
//

import AppKit
import SwiftUI

/// Shared application delegate for both macOS entry paths:
/// - SwiftUI path (macOS 11+): installed via `@NSApplicationDelegateAdaptor`.
/// - AppKit path (macOS 10.15): installed by `LegacyMacBootstrap`.
final class AppDelegate: NSObject, NSApplicationDelegate {
    /// True only on the Catalina bootstrap path, where this delegate also
    /// owns the window and the standard menu (the SwiftUI `App` scene does
    /// that itself on macOS 11+).
    private let ownsWindow: Bool
    private var window: NSWindow?

    init(ownsWindow: Bool = false) {
        self.ownsWindow = ownsWindow
        super.init()
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        if ownsWindow {
            showWindow()
            LegacyMenu.install()
        }

        // Maintenance hooks used to hang off `.task` (macOS 12+); the launch
        // callback covers macOS 10.15 as well.
        Task { @MainActor in
            await MaintenanceHooks.runIfNeeded()
        }
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        ownsWindow
    }

    private func showWindow() {
        let contentRect = NSRect(x: 0, y: 0, width: 520, height: 640)
        let window = NSWindow(
            contentRect: contentRect,
            styleMask: [.titled, .closable, .miniaturizable, .resizable],
            backing: .buffered,
            defer: false
        )
        window.title = "VisualAlarm"
        window.contentView = NSHostingView(rootView: ContentView())
        window.center()
        window.makeKeyAndOrderFront(nil)
        self.window = window

        // Activation only sticks once the run loop is running (same gotcha as
        // the runner bootstrap).
        DispatchQueue.main.async {
            NSApp.activate(ignoringOtherApps: true)
        }
    }
}

/// macOS 10.15 bootstrap: the SwiftUI `App`/`Scene` lifecycle starts at
/// macOS 11, so Catalina runs the same `ContentView` inside a plain AppKit
/// application.
enum LegacyMacBootstrap {
    static func run() {
        let app = NSApplication.shared
        let delegate = AppDelegate(ownsWindow: true)
        app.delegate = delegate
        app.run()
    }
}

/// Minimal standard menu for the AppKit path (the SwiftUI app lifecycle
/// provides one automatically on macOS 11+).
enum LegacyMenu {
    static func install() {
        let mainMenu = NSMenu()

        let appItem = NSMenuItem()
        mainMenu.addItem(appItem)
        let appMenu = NSMenu(title: "VisualAlarm")
        appMenu.addItem(
            withTitle: "About VisualAlarm",
            action: #selector(NSApplication.orderFrontStandardAboutPanel(_:)),
            keyEquivalent: ""
        )
        appMenu.addItem(NSMenuItem.separator())
        appMenu.addItem(
            withTitle: "Quit VisualAlarm",
            action: #selector(NSApplication.terminate(_:)),
            keyEquivalent: "q"
        )
        appItem.submenu = appMenu

        let editItem = NSMenuItem()
        mainMenu.addItem(editItem)
        let editMenu = NSMenu(title: "Edit")
        editMenu.addItem(
            withTitle: "Undo",
            action: Selector(("undo:")),
            keyEquivalent: "z"
        )
        editMenu.addItem(
            withTitle: "Redo",
            action: Selector(("redo:")),
            keyEquivalent: "Z"
        )
        editMenu.addItem(NSMenuItem.separator())
        editMenu.addItem(
            withTitle: "Cut",
            action: #selector(NSText.cut(_:)),
            keyEquivalent: "x"
        )
        editMenu.addItem(
            withTitle: "Copy",
            action: #selector(NSText.copy(_:)),
            keyEquivalent: "c"
        )
        editMenu.addItem(
            withTitle: "Paste",
            action: #selector(NSText.paste(_:)),
            keyEquivalent: "v"
        )
        editMenu.addItem(
            withTitle: "Select All",
            action: #selector(NSText.selectAll(_:)),
            keyEquivalent: "a"
        )
        editItem.submenu = editMenu

        NSApp.mainMenu = mainMenu
    }
}
