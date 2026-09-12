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
    var hour: Int {
        didSet { hour = Self.clampedHour(hour) }
    }
    var minute: Int {
        didSet { minute = Self.clampedMinute(minute) }
    }
    var isEnabled: Bool
    var weekdays: Set<Int> {
        didSet { weekdays = Self.filteredWeekdays(weekdays) }
    }

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
        // Property observers don't run during initialization, so the
        // normalization has to be applied here explicitly as well.
        self.hour = Self.clampedHour(hour)
        self.minute = Self.clampedMinute(minute)
        self.isEnabled = isEnabled
        self.weekdays = Self.filteredWeekdays(weekdays)
    }

    private static func clampedHour(_ value: Int) -> Int {
        min(max(value, 0), 23)
    }

    private static func clampedMinute(_ value: Int) -> Int {
        min(max(value, 0), 59)
    }

    private static func filteredWeekdays(_ weekdays: Set<Int>) -> Set<Int> {
        Set(weekdays.filter(allWeekdays.contains))
    }
}
