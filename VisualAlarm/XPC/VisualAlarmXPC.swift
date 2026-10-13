/**
 * File: VisualAlarmXPC.swift
 * Created: 2026-10-13
 */

import Foundation

/// Identifiers used to address the bundled XPC services.
enum XPCServiceName {
    static let agent = "co.denis.VisualAlarm.agent"
    static let runner = "co.denis.VisualAlarm.runner"
}

/// Transport-safe snapshot of an `Alarm`. `@objc` XPC interfaces cannot carry
/// Swift structs directly, so alarms cross the boundary in this form.
struct XPCAlarm: Codable, Equatable {
    let id: String
    let hour: Int
    let minute: Int
    let label: String
    let isEnabled: Bool
    let weekdays: [Int]

    init(_ alarm: Alarm) {
        id = alarm.id.uuidString
        hour = alarm.hour
        minute = alarm.minute
        label = alarm.label
        isEnabled = alarm.isEnabled
        weekdays = alarm.weekdays.sorted()
    }

    /// Declared explicitly: defining `init(_:)` above would otherwise suppress
    /// Swift's implicit memberwise initializer, which tests rely on to build
    /// deliberately malformed payloads.
    init(
        id: String,
        hour: Int,
        minute: Int,
        label: String,
        isEnabled: Bool,
        weekdays: [Int]
    ) {
        self.id = id
        self.hour = hour
        self.minute = minute
        self.label = label
        self.isEnabled = isEnabled
        self.weekdays = weekdays
    }

    var alarm: Alarm? {
        guard let uuid = UUID(uuidString: id) else { return nil }
        return Alarm(
            id: uuid,
            label: label,
            hour: hour,
            minute: minute,
            isEnabled: isEnabled,
            weekdays: Set(weekdays)
        )
    }
}

/// Serializes to a property-list-safe payload. `@objc` protocols can only carry
/// ObjC-representable types, and Swift structs are not among them, so alarms
/// travel as encoded `Data`.
extension XPCAlarm {
    func encoded() throws -> Data {
        try JSONEncoder().encode(self)
    }

    static func decode(_ data: Data) throws -> XPCAlarm {
        try JSONDecoder().decode(XPCAlarm.self, from: data)
    }
}

/// Agent service: owns the resident scheduler loop.
@objc protocol AlarmSchedulerServiceProtocol {
    /// Re-reads the store and re-anchors the scheduler's catch-up window.
    func resyncScheduler(reply: @escaping () -> Void)
    /// Number of alarms the scheduler currently sees.
    func alarmCount(reply: @escaping (Int) -> Void)
}

/// Runner service: presents the alarm window and its effects.
@objc protocol AlarmRunnerServiceProtocol {
    /// Shows the stop window for an alarm and starts sound + brightness flicker.
    func presentAlarm(_ payload: Data, reply: @escaping (Bool) -> Void)
    /// Stops effects and closes the window.
    func dismissAlarm(reply: @escaping (Bool) -> Void)
}