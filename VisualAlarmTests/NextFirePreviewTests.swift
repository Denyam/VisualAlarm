import Foundation
import Testing

@testable import VisualAlarm

struct NextFirePreviewTests {

    private let berlin: Calendar = {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "Europe/Berlin")!
        return calendar
    }()

    /// Noon of whatever day the suite runs on, so "Today"/"Tomorrow"
    /// classifications are deterministic relative to the real clock.
    private var todayNoon: Date {
        var components = berlin.dateComponents([.year, .month, .day], from: Date())
        components.hour = 12
        return berlin.date(from: components)!
    }

    private func daysFromNow(_ days: Int) -> Date {
        berlin.date(byAdding: .day, value: days, to: todayNoon)!
    }

    @Test func laterTodayShowsToday() {
        let alarm = Alarm(hour: 23, minute: 5)

        #expect(
            NextFirePreview.text(for: alarm, now: todayNoon, calendar: berlin)
                == "Today 23:05"
        )
    }

    @Test func afterFireTimeShowsTomorrow() {
        // Midnight is always strictly in the future relative to noon.
        let alarm = Alarm(hour: 0, minute: 30)

        #expect(
            NextFirePreview.text(for: alarm, now: todayNoon, calendar: berlin)
                == "Tomorrow 00:30"
        )
    }

    @Test func furtherOutShowsWeekdayAbbreviation() {
        // Four days out can never be today or tomorrow.
        let targetWeekday = berlin.component(.weekday, from: daysFromNow(4))
        let alarm = Alarm(hour: 9, minute: 15, weekdays: [targetWeekday])

        let caption = NextFirePreview.text(
            for: alarm,
            now: todayNoon,
            calendar: berlin
        )

        let knownAbbreviations = ["Sun", "Mon", "Tue", "Wed", "Thu", "Fri", "Sat"]
        #expect(caption != nil)
        #expect(caption?.hasSuffix("09:15") == true)
        #expect(
            knownAbbreviations.contains { caption?.hasPrefix("\($0) ") == true }
        )
    }

    @Test func disabledAlarmHasNoCaption() {
        let alarm = Alarm(hour: 7, minute: 0, isEnabled: false)

        #expect(
            NextFirePreview.text(for: alarm, now: todayNoon, calendar: berlin) == nil
        )
    }
}
