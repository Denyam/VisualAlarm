/**
 * File: IOSAlarmScheduler.swift
 * Created: 2026-08-25
 */

#if os(iOS)
import Foundation
import UserNotifications

/// Schedules iOS local notifications for alarms. Repeating
/// `UNCalendarNotificationTrigger` requests stand in for the macOS resident
/// agent: the system delivers sound + banner while the app is closed; visual
/// effects run only when the app is foreground or the notification is tapped.
///
/// Requests use stable identifiers derived from alarm ID (plus weekday), so
/// `sync` can diff pending requests against the desired state and touch only
/// what changed.
final class IOSAlarmScheduler {
    static let identifierPrefix = "co.denis.VisualAlarm.alarm."

    private let center: any NotificationScheduling
    private let calendar: Calendar

    init(
        center: any NotificationScheduling = UNUserNotificationCenter.current(),
        calendar: Calendar = .current
    ) {
        self.center = center
        self.calendar = calendar
    }

    // MARK: - Pure helpers (unit-tested directly)

    /// Stable identifier for one alarm occurrence stream; `weekday` nil = daily.
    static func identifier(for alarm: Alarm, weekday: Int?) -> String {
        let suffix = weekday.map { ".wd\($0)" } ?? ".daily"
        return "\(identifierPrefix)\(alarm.id.uuidString)\(suffix)"
    }

    static func trigger(for alarm: Alarm, weekday: Int?) -> UNCalendarNotificationTrigger {
        var components = DateComponents()
        components.hour = alarm.hour
        components.minute = alarm.minute
        components.weekday = weekday
        return UNCalendarNotificationTrigger(dateMatching: components, repeats: true)
    }

    static func content(for alarm: Alarm) -> UNMutableNotificationContent {
        let content = UNMutableNotificationContent()
        content.title = alarm.label.isEmpty ? "Alarm" : alarm.label
        content.body = String(format: "%02d:%02d", alarm.hour, alarm.minute)
        content.sound = .default
        return content
    }

    /// Identifier → desired trigger map across all enabled alarms.
    static func desiredRequests(
        for alarms: [Alarm]
    ) -> [String: UNCalendarNotificationTrigger] {
        var result: [String: UNCalendarNotificationTrigger] = [:]
        for alarm in alarms where alarm.isEnabled {
            if alarm.weekdays.isEmpty {
                result[identifier(for: alarm, weekday: nil)] =
                    trigger(for: alarm, weekday: nil)
            } else {
                for weekday in alarm.weekdays {
                    result[identifier(for: alarm, weekday: weekday)] =
                        trigger(for: alarm, weekday: weekday)
                }
            }
        }
        return result
    }

    /// Whether a pending request must be replaced: absent, or its time
    /// components no longer match the desired trigger.
    static func needsUpdate(
        pending: [UNNotificationRequest],
        identifier: String,
        desired: UNCalendarNotificationTrigger
    ) -> Bool {
        guard let existing = pending.first(where: { $0.identifier == identifier }) else {
            return true
        }
        guard
            let trigger = existing.trigger as? UNCalendarNotificationTrigger
        else { return true }

        let current = trigger.dateComponents
        let wanted = desired.dateComponents
        return current.hour != wanted.hour
            || current.minute != wanted.minute
            || current.weekday != wanted.weekday
            || trigger.repeats != desired.repeats
    }

    // MARK: - Sync

    /// Reconciles pending notification requests with the alarm list.
    func sync(alarms: [Alarm]) async {
        let desired = Self.desiredRequests(for: alarms)
        let pending = await center.pendingRequests()
            .filter { $0.identifier.hasPrefix(Self.identifierPrefix) }

        let desiredIDs = Set(desired.keys)
        let stale = pending
            .map(\.identifier)
            .filter { !desiredIDs.contains($0) }
        if !stale.isEmpty {
            await center.removePendingRequests(withIdentifiers: stale)
        }

        for (identifier, trigger) in desired
        where Self.needsUpdate(
            pending: pending,
            identifier: identifier,
            desired: trigger
        ) {
            let alarmID = Self.alarmID(fromIdentifier: identifier)
            let alarm = alarms.first { $0.id == alarmID }
            let request = UNNotificationRequest(
                identifier: identifier,
                content: alarm.map(Self.content) ?? UNMutableNotificationContent(),
                trigger: trigger
            )
            // Adding a request with an existing identifier replaces it.
            try? await center.schedule(request)
        }
    }

    static func alarmID(fromIdentifier identifier: String) -> UUID? {
        let stripped = identifier
            .dropFirst(identifierPrefix.count)
        let base = stripped.split(separator: ".").first ?? ""
        return UUID(uuidString: String(base))
    }
}
#endif
