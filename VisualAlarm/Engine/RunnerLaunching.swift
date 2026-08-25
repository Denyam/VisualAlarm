/**
 * File: RunnerLaunching.swift
 * Created: 2026-08-24
 */

import Foundation

/// Spawns the alarm window process for a due alarm and records what is
/// firing so the runner can present specifics.
protocol RunnerLaunching {
    func launch(firingAlarm alarm: Alarm)
}
