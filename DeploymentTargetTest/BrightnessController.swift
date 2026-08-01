//
//  BrightnessController.swift
//  DeploymentTargetTest
//
//  Created by Denis on 01.08.2026.
//

import Foundation
import IOKit

/// Utility that lets you set the screen brightness via the IOKit “IODisplay” interface.
class BrightnessController {

    /// Sets the screen backlight level.
    ///
    /// - Parameter brightnessValue: Normalized value between 0 (off) and 1 (maximum).
    static func setScreenBrightness(_ brightnessValue: Float) {
        var iterator = io_iterator_t()

        // Find all services that expose a display connection
        let result = IOServiceGetMatchingServices(
            kIOMasterPortDefault,
            IOServiceMatching("IODisplayConnect"),
            &iterator
        )

        guard result == KERN_SUCCESS else { return }

        while case let service = IOIteratorNext(iterator), service != 0 {
            var currentBrightness: Float = 0.0

            // Read the current brightness
            IODisplayGetFloatParameter(
                service,
                0,
                kIODisplayBrightnessKey as CFString,
                &currentBrightness
            )
            print("current brightness: \(Int(currentBrightness * 100))%")

            // Apply the new value
            IODisplaySetFloatParameter(
                service,
                0,
                kIODisplayBrightnessKey as CFString,
                brightnessValue
            )

            // Verify the change
            IODisplayGetFloatParameter(
                service,
                0,
                kIODisplayBrightnessKey as CFString,
                &currentBrightness
            )
            print("new custom brightness: \(Int(currentBrightness * 100))%")

            IOObjectRelease(service)
        }
    }
}
