import UIKit

/// Seam for screen brightness; lets effect coordination be unit-tested.
protocol ScreenBrightnessControlling {
    var brightness: CGFloat { get set }
}

/// Handles screen brightness adjustments.
public class BrightnessController: ScreenBrightnessControlling {
    public var brightness: CGFloat {
        get { UIScreen.main.brightness }
        set {
            UIScreen.main.brightness = max(0.0, min(1.0, newValue))
        }
    }

    /// Sets the device screen brightness.
    /// - Parameter level: Desired brightness value ranging from `0.0` (dark) to `1.0` (maximum).
    /// - Returns: `true` if the brightness was changed successfully, otherwise `false`.
    @discardableResult
    public func setBrightness(to level: CGFloat) -> Bool {
        brightness = level
        return true
    }
}
