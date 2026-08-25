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
    func fire() {
        UINotificationFeedbackGenerator().notificationOccurred(.error)
    }
}
#endif
