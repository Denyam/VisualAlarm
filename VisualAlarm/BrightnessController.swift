#if os(iOS) || os(macOS)
import UIKit
#endif

/// Handles screen brightness adjustments.
public class BrightnessController {
    /// Sets the device screen brightness.
    /// - Parameter level: Desired brightness value ranging from `0.0` (dark) to `1.0` (maximum).
    /// - Returns: `true` if the brightness was changed successfully, otherwise `false`.
    @discardableResult
    public func setBrightness(to level: CGFloat) -> Bool {
        // Clamp level to valid range
        let clamped = max(0.0, min(1.0, level))
        #if os(iOS)
        UIScreen.main.brightness = clamped
        return true
        #else
        // macOS does not provide a direct brightness API in this context.
        return false
        #endif
    }
}
#if os(macOS)
// Provide a stub for macOS build to satisfy references.
public extension BrightnessController {
    func setBrightness(to macLevel: CGFloat) -> Bool { false }
}
#endif
