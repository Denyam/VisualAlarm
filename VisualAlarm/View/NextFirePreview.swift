/**
 * File: NextFirePreview.swift
 * Created: 2026-08-23
 */

import Foundation

/// Human-readable "fires next" captions for the alarm list.
enum NextFirePreview {
    /// Fixed English abbreviations so captions are stable regardless of the
    /// user's system locale.
    private static let weekdayAbbreviations = [
        "Sun", "Mon", "Tue", "Wed", "Thu", "Fri", "Sat",
    ]

    /// "Today 07:30", "Tomorrow 07:30", or the next matching weekday
    /// ("Mon 06:45"); nil when the alarm never fires.
    static func text(
        for alarm: Alarm,
        now: Date,
        calendar: Calendar = .current
    ) -> String? {
        guard
            let next = NextFireDateCalculator.nextFireDate(
                for: alarm,
                after: now,
                calendar: calendar
            )
        else { return nil }

        let time = calendar.dateComponents([.hour, .minute], from: next)
        let timeText = String(
            format: "%02d:%02d",
            time.hour ?? 0,
            time.minute ?? 0
        )

        if calendar.isDateInToday(next) {
            return "Today \(timeText)"
        }
        if calendar.isDateInTomorrow(next) {
            return "Tomorrow \(timeText)"
        }
        let weekdayIndex = calendar.component(.weekday, from: next) - 1
        return "\(weekdayAbbreviations[weekdayIndex]) \(timeText)"
    }
}
