/**
 * File: Alarm.swift
 * Created: 2026-08-22
 */

import Foundation

struct Alarm: Identifiable, Codable, Equatable, Hashable {
    /// Values match `Calendar.weekday` (1 = Sunday … 7 = Saturday).
    /// An empty set means the alarm repeats every day.
    static let allWeekdays: Set<Int> = [1, 2, 3, 4, 5, 6, 7]

    var id: UUID
    var label: String
    var hour: Int
    var minute: Int
    var isEnabled: Bool
    var weekdays: Set<Int>

    init(
        id: UUID = UUID(),
        label: String = "",
        hour: Int,
        minute: Int,
        isEnabled: Bool = true,
        weekdays: Set<Int> = []
    ) {
        self.id = id
        self.label = label
        self.hour = min(max(hour, 0), 23)
        self.minute = min(max(minute, 0), 59)
        self.isEnabled = isEnabled
        self.weekdays = Set(weekdays.filter(Self.allWeekdays.contains))
    }
}
