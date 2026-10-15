/**
 * File: VisualAlarmXPCProtocols.swift
 * Created: 2026-10-14
 *
 * Shared XPC protocols for communication between the main app, agent, and runner.
 * These protocols define the interface for alarm scheduling and presentation.
 * Alarms cross the boundary as JSON-encoded Data because Swift structs cannot be
 * @objc parameters.
 */

import Foundation

/// Protocol for the agent XPC service (scheduling alarms).
@objc
protocol AlarmSchedulerProtocol {
    /// Schedule a new alarm (JSON-encoded Alarm as Data).
    func scheduleAlarm(_ alarmData: Data, reply: @escaping (Bool) -> Void)

    /// Cancel an alarm by ID.
    func cancelAlarm(id: String, reply: @escaping (Bool) -> Void)

    /// Get all pending alarms (JSON-encoded [Alarm] as Data).
    func getPendingAlarms(reply: @escaping (Data?) -> Void)

    /// Replace the agent's entire alarm list (JSON-encoded [Alarm] as Data).
    /// The agent persists it — the agent owns alarm storage.
    func syncAlarms(_ alarmsData: Data, reply: @escaping (Bool) -> Void)

    /// Resync the scheduler (e.g., after wake from sleep).
    func resync(reply: @escaping () -> Void)
}

/// Protocol for the runner XPC service (showing alarm window).
@objc
protocol AlarmRunnerProtocol {
    /// Show the alarm window for the given alarm.
    func showAlarmWindow(alarmID: String, label: String, reply: @escaping (Bool) -> Void)

    /// Close the alarm window.
    func closeAlarmWindow(reply: @escaping (Bool) -> Void)
}

/// Helper for encoding/decoding Alarm to/from JSON Data for XPC transport.
enum XPCRepresentation {
    static func encode(_ alarm: Alarm) -> Data? {
        try? JSONEncoder().encode(alarm)
    }
    
    static func encode(_ alarms: [Alarm]) -> Data? {
        try? JSONEncoder().encode(alarms)
    }
    
    static func decodeAlarm(_ data: Data) -> Alarm? {
        try? JSONDecoder().decode(Alarm.self, from: data)
    }
    
    static func decodeAlarms(_ data: Data) -> [Alarm]? {
        try? JSONDecoder().decode([Alarm].self, from: data)
    }
}