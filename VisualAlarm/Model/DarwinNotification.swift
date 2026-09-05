/**
 * File: DarwinNotification.swift
 * Created: 2026-08-24
 */

/// Cross-process notifications delivered through the Darwin notify center.
/// Darwin notifications carry no payload — observers re-read shared state
/// (e.g. `AlarmStore`) when they arrive.
enum DarwinNotification: String {
    /// Some process changed `alarms.json`; others should reload it.
    case alarmsDidChange = "co.denis.VisualAlarm.alarms.didChange"
    /// The agent is about to launch the runner for a due alarm.
    case alarmShouldFire = "co.denis.VisualAlarm.alarm.shouldFire"
}
