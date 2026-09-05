/**
 * File: AlarmTests.swift
 * Created: 2026-08-22
 */

import Foundation
import Testing

@testable import VisualAlarm

struct AlarmTests {

    @Test func codableRoundTripPreservesAllFields() throws {
        let alarm = Alarm(
            label: "Wake up",
            hour: 7,
            minute: 30,
            isEnabled: false,
            weekdays: [2, 4, 6]
        )

        let data = try JSONEncoder().encode(alarm)
        let decoded = try JSONDecoder().decode(Alarm.self, from: data)

        #expect(decoded == alarm)
    }

    @Test func clampsHourAndMinuteIntoValidRange() {
        #expect(Alarm(hour: 27, minute: 75).hour == 23)
        #expect(Alarm(hour: 27, minute: 75).minute == 59)
        #expect(Alarm(hour: -3, minute: -9).hour == 0)
        #expect(Alarm(hour: -3, minute: -9).minute == 0)
    }

    @Test func dropsWeekdayValuesOutOfRange() {
        let alarm = Alarm(hour: 1, minute: 0, weekdays: [0, 1, 4, 8])
        #expect(alarm.weekdays == [1, 4])
    }

    @Test func clampsOnMutationAfterInitialization() {
        var alarm = Alarm(hour: 6, minute: 30)

        alarm.hour = 99
        alarm.minute = -5
        alarm.weekdays = [2, 0, 11]

        #expect(alarm.hour == 23)
        #expect(alarm.minute == 0)
        #expect(alarm.weekdays == [2])
    }

    @Test func emptyWeekdaySetStaysEmpty() {
        let alarm = Alarm(hour: 5, minute: 15, weekdays: [])
        #expect(alarm.weekdays.isEmpty)
    }

    @Test func uniqueDefaultIdentifiers() {
        let first = Alarm(hour: 1, minute: 1)
        let second = Alarm(hour: 2, minute: 2)
        #expect(first.id != second.id)
    }
}
