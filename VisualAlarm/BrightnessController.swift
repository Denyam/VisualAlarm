import UIKit

/// Handles screen brightness adjustments.
public class BrightnessController {
    /// Sets the device screen brightness.
    /// - Parameter level: Desired brightness value ranging from `0.0` (dark) to `1.0` (maximum).
    /// - Returns: `true` if the brightness was changed successfully, otherwise `false`.
    @discardableResult
    public func setBrightness(to level: CGFloat) -> Bool {
        // Clamp level to valid range
        let clamped = max(0.0, min(1.0, level))
        guard UIScreen.main.responds(to: #selector(setter: UIScreen.brightness)) else { return false }
        UIScreen.main.brightness = clamped
        return true
    }
}
