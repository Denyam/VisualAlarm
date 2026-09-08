/**
 * File: HapticSignaling.swift
 * Created: 2026-08-25
 */

#if os(iOS)
import UIKit

/// Seam for haptic feedback during alarm effects.
protocol HapticSignaling {
    func fire()
}

struct AlertHaptics: HapticSignaling {
    private let generator = UINotificationFeedbackGenerator()

    func fire() {
        generator.notificationOccurred(.error)
    }
}
#endif
