//
//  VisualAlarmApp.swift
//  VisualAlarm
//
//  Created by Denis on 14.08.2026.
//

import SwiftUI

/// The SwiftUI app scene. Requires macOS 11 (the `App`/`Scene` lifecycle
/// floor); on macOS 10.15 `main.swift` bootstraps AppKit instead.
@available(macOS 11.0, *)
struct VisualAlarmApp: App {
    #if os(macOS)
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    #endif

    var body: some Scene {
        WindowGroup {
            ContentView()
        }
    }
}
