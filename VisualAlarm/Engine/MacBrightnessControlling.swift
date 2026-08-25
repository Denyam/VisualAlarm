/**
 * File: MacBrightnessControlling.swift
 * Created: 2026-08-22
 */

#if os(macOS)
import Foundation

/// Abstraction over display brightness manipulation; the seam that keeps
/// effect logic unit-testable without touching real hardware.
protocol MacBrightnessControlling {
    /// Remembers current levels of all displays.
    func storeCurrentLevels()
    /// Sets every known display to the given level. Returns success.
    @discardableResult
    func setAllDisplays(to value: Float) -> Bool
    /// Puts every display back to its snapshotted level.
    func restoreStoredLevels()
}
#endif

