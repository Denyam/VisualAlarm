/**
 * File: AlarmEditorModelTests.swift
 * Created: 2026-08-23
 */

import Foundation
import Testing

@testable import VisualAlarm

@MainActor
struct AlarmEditorModelTests {

    private let calendar: Calendar = {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "Europe/Berlin")!
        return calendar
    }()

    private func components(of date: Date) -> DateComponents {
        calendar.dateComponents([.hour, .minute], from: date)
    }

    @Test func newAlarmDefaultsToDailySeven() {
        var saved: [Alarm] = []
        let model = AlarmEditorModel(alarm: nil, calendar: calendar) { saved.append($0) }

        #expect(model.isEditingExisting == false)
        #expect(model.label.isEmpty)
        #expect(model.weekdays.isEmpty) // daily
        #expect(components(of: model.time).hour == 7)
        #expect(components(of: model.time).minute == 0)

        model.save()

        #expect(saved.count == 1)
        #expect(saved[0].hour == 7 && saved[0].minute == 0)
    }

    @Test func editingPreservesIdentifierAndFields() {
        let existing = Alarm(
            label: "Gym",
            hour: 6,
            minute: 30,
            isEnabled: false,
            weekdays: [2, 4]
        )
        var saved: [Alarm] = []
        let model = AlarmEditorModel(alarm: existing, calendar: calendar) { saved.append($0) }

        #expect(model.isEditingExisting)
        model.label = "  Gym session  "

        let result = model.save()

        #expect(result.id == existing.id)
        #expect(result.label == "Gym session") // trimmed
        #expect(result.hour == 6 && result.minute == 30)
        #expect(result.weekdays == [2, 4])
        #expect(result.isEnabled == false)
        #expect(saved == [result])
    }

    @Test func togglingWeekdayChipsRoundTrips() {
        var saved: [Alarm] = []
        let model = AlarmEditorModel(alarm: nil, calendar: calendar) { saved.append($0) }

        model.weekdays = [1, 3, 7]
        let result = model.save()

        #expect(result.weekdays == [1, 3, 7])
    }
}
