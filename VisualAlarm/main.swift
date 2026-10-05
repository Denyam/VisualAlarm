//
//  main.swift
//  VisualAlarm
//
//  Explicit entry point for both platforms: the SwiftUI `App` lifecycle
//  requires macOS 11 / iOS 14, and the macOS floor is 10.15, so `@main`
//  cannot be used. On Catalina the app bootstraps through AppKit instead.
//

import Foundation
import SwiftUI

#if os(macOS)
if #available(macOS 11.0, *) {
    VisualAlarmApp.main()
} else {
    LegacyMacBootstrap.run()
}
#else
VisualAlarmApp.main()
#endif
