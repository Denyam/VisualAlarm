/**
 * File: BrightnessController.swift
 * Created: 2026-08-22
 */

#if os(iOS)
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
}
#endif
