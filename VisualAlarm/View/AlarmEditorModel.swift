/**
 * File: AlarmEditorModel.swift
 * Created: 2026-08-23
 */

import Combine
import Foundation

/// Backing model for the add/edit alarm sheet: holds the form state, derives
/// a validated `Alarm`, and hands it to the provided save closure.
@MainActor
final class AlarmEditorModel: ObservableObject {
    @Published var label: String
    @Published var time: Date
    @Published var weekdays: Set<Int>
    @Published var isEnabled: Bool

    let isEditingExisting: Bool

    private let originalID: UUID?
    private let calendar: Calendar
    private let onSave: (Alarm) -> Void

    /// - Parameter alarm: `nil` creates a brand-new alarm (default 07:00 daily).
    init(
        alarm: Alarm?,
        calendar: Calendar = .current,
        onSave: @escaping (Alarm) -> Void
    ) {
        let source = alarm ?? Alarm(hour: 7, minute: 0)

        self.originalID = source.id
        self.isEditingExisting = alarm != nil
        self.calendar = calendar
        self.onSave = onSave
        self.label = source.label
        self.weekdays = source.weekdays
        self.isEnabled = source.isEnabled
        self.time = AlarmEditorModel.timeDate(
            hour: source.hour,
            minute: source.minute,
            calendar: calendar
        )
    }

    /// Builds the alarm from the form and reports it via `onSave`.
    /// Returns the saved alarm for convenience.
    @discardableResult
    func save() -> Alarm {
        let components = calendar.dateComponents([.hour, .minute], from: time)
        let alarm = Alarm(
            id: originalID ?? UUID(),
            label: label.trimmingCharacters(in: .whitespacesAndNewlines),
            hour: components.hour ?? 0,
            minute: components.minute ?? 0,
            isEnabled: isEnabled,
            weekdays: weekdays
        )
        onSave(alarm)
        return alarm
    }

    private static func timeDate(
        hour: Int,
        minute: Int,
        calendar: Calendar
    ) -> Date {
        var components = DateComponents()
        components.hour = hour
        components.minute = minute
        return calendar.date(from: components) ?? Date()
    }
}
