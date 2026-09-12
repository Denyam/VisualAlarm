/**
 * File: NextFireDateCalculatorTests.swift
 * Created: 2026-08-23
 */

import Foundation
import Testing

@testable import VisualAlarm

struct NextFireDateCalculatorTests {

    private let berlin: Calendar = {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "Europe/Berlin")!
        return calendar
    }()

    private func date(
        _ year: Int, _ month: Int, _ day: Int, _ hour: Int, _ minute: Int
    ) -> Date {
        berlin.date(
            from: DateComponents(
                year: year, month: month, day: day, hour: hour, minute: minute
            )
        )!
    }

    private func components(of date: Date) -> DateComponents {
        berlin.dateComponents([.year, .month, .day, .hour, .minute], from: date)
    }

    private func assertNext(
        _ result: Date?,
        equalsYear y: Int, _ month: Int, _ day: Int, _ hour: Int, _ minute: Int,
        sourceLocation: SourceLocation = #_sourceLocation
    ) {
        guard let result else {
            Issue.record("Expected a fire date but got nil", sourceLocation: sourceLocation)
            return
        }
        let actual = components(of: result)
        #expect(actual.year == y, "year", sourceLocation: sourceLocation)
        #expect(actual.month == month, "month", sourceLocation: sourceLocation)
        #expect(actual.day == day, "day", sourceLocation: sourceLocation)
        #expect(actual.hour == hour, "hour", sourceLocation: sourceLocation)
        #expect(actual.minute == minute, "minute", sourceLocation: sourceLocation)
    }

    @Test func dailyAlarmLaterToday() {
        let alarm = Alarm(hour: 7, minute: 30)

        let next = NextFireDateCalculator.nextFireDate(
            for: alarm,
            after: date(2026, 8, 28, 6, 0),
            calendar: berlin
        )

        assertNext(next, equalsYear: 2026, 8, 28, 7, 30)
    }

    @Test func dailyAlarmFallsToTomorrowAfterFireTime() {
        let alarm = Alarm(hour: 7, minute: 30)

        let next = NextFireDateCalculator.nextFireDate(
            for: alarm,
            after: date(2026, 8, 28, 22, 0),
            calendar: berlin
        )

        assertNext(next, equalsYear: 2026, 8, 29, 7, 30)
    }

    @Test func exactFireMomentIsStrictlyBeforeResult() {
        let alarm = Alarm(hour: 7, minute: 30)

        let next = NextFireDateCalculator.nextFireDate(
            for: alarm,
            after: date(2026, 8, 28, 7, 30),
            calendar: berlin
        )

        assertNext(next, equalsYear: 2026, 8, 29, 7, 30)
    }

    @Test func disabledAlarmNeverFires() {
        let alarm = Alarm(hour: 7, minute: 30, isEnabled: false)

        let next = NextFireDateCalculator.nextFireDate(
            for: alarm,
            after: date(2026, 8, 28, 6, 0),
            calendar: berlin
        )

        #expect(next == nil)
    }

    @Test func singleWeekdaySkipsForwardAcrossTheWeekend() {
        // 2026-08-28 is a Friday; Mondays are weekday 2.
        let alarm = Alarm(hour: 6, minute: 45, weekdays: [2])

        let next = NextFireDateCalculator.nextFireDate(
            for: alarm,
            after: date(2026, 8, 28, 20, 0),
            calendar: berlin
        )

        assertNext(next, equalsYear: 2026, 8, 31, 6, 45)
    }

    @Test func picksNearestOfSeveralWeekdays() {
        // From Sunday evening 2026-08-30: Monday (2) beats Wednesday (4).
        let alarm = Alarm(hour: 9, minute: 0, weekdays: [4, 2])

        let next = NextFireDateCalculator.nextFireDate(
            for: alarm,
            after: date(2026, 8, 30, 21, 0),
            calendar: berlin
        )

        assertNext(next, equalsYear: 2026, 8, 31, 9, 0)
    }

    @Test func springForwardShiftsNonexistentTimeForward() {
        // Berlin starts DST on 2026-03-29: 02:00 jumps to 03:00, so a
        // 02:30 alarm does not exist that morning; `.nextTime` resolves it
        // to the first valid instant after the gap — 03:00 sharp.
        let alarm = Alarm(hour: 2, minute: 30)

        let next = NextFireDateCalculator.nextFireDate(
            for: alarm,
            after: date(2026, 3, 28, 12, 0),
            calendar: berlin
        )

        assertNext(next, equalsYear: 2026, 3, 29, 3, 0)
    }

    @Test func fallBackKeepsFirstInstanceOfRepeatedHour() {
        // Berlin ends DST on 2026-10-25: 02:30 occurs twice; the first
        // occurrence (still summer offset) must be chosen.
        let alarm = Alarm(hour: 2, minute: 30)

        let next = NextFireDateCalculator.nextFireDate(
            for: alarm,
            after: date(2026, 10, 24, 12, 0),
            calendar: berlin
        )

        assertNext(next, equalsYear: 2026, 10, 25, 2, 30)
    }
}
