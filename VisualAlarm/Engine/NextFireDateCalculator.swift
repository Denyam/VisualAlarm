/**
 * File: NextFireDateCalculator.swift
 * Created: 2026-08-23
 */

import Foundation

/// Computes when an alarm fires next. Pure functions over `Calendar` using
/// the `.nextTime` DST policy so skipped/repeated wall-clock times around
/// daylight-saving transitions resolve sensibly.
enum NextFireDateCalculator {
    /// Next fire instant strictly after `date`; nil for disabled alarms.
    /// An alarm with an empty weekday set fires every day.
    static func nextFireDate(
        for alarm: Alarm,
        after date: Date,
        calendar: Calendar = .current
    ) -> Date? {
        guard alarm.isEnabled else { return nil }

        var timeComponents = DateComponents()
        timeComponents.hour = alarm.hour
        timeComponents.minute = alarm.minute

        guard !alarm.weekdays.isEmpty else {
            return calendar.nextDate(
                after: date,
                matching: timeComponents,
                matchingPolicy: .nextTime
            )
        }

        return alarm.weekdays
            .sorted()
            .compactMap { weekday in
                var components = timeComponents
                components.weekday = weekday
                return calendar.nextDate(
                    after: date,
                    matching: components,
                    matchingPolicy: .nextTime
                )
            }
            .min()
    }
}
