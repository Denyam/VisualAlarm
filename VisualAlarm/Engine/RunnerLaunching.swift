/**
 * File: RunnerLaunching.swift
 * Created: 2026-08-24
 */

#if os(macOS)
import Foundation

/// Hands a due (or test) alarm to the runner process so it can present the
/// alarm window with the alarm's specifics.
protocol RunnerLaunching {
    func launch(firingAlarm alarm: Alarm)
}
#endif
