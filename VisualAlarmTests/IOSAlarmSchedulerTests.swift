/**
 * File: IOSAlarmSchedulerTests.swift
 * Created: 2026-08-25
 */

#if os(iOS)
import Foundation
import Testing
import UserNotifications

@testable import VisualAlarm

/// In-memory stand-in for the system notification center.
final class MockNotificationScheduling: NotificationScheduling, @unchecked Sendable {
    private let lock = NSLock()
    private var requests: [String: UNNotificationRequest] = [:]
    var authorizationGranted = true
    private(set) var authorizationRequested = false

    func requestAuthorizationIfNeeded() async -> Bool {
        authorizationRequested = true
        return authorizationGranted
    }

    func schedule(_ request: UNNotificationRequest) async throws {
        lock.lock()
        requests[request.identifier] = request // system replaces same identifier
        lock.unlock()
    }

    func removePendingRequests(withIdentifiers identifiers: [String]) async {
        lock.lock()
        for id in identifiers { requests.removeValue(forKey: id) }
        lock.unlock()
    }

    func pendingRequests() async -> [UNNotificationRequest] {
        lock.lock()
        defer { lock.unlock() }
        return Array(requests.values)
    }
}

struct IOSAlarmSchedulerTests {

    private func makeRequest(
        _ identifier: String,
        hour: Int?,
        minute: Int?,
        weekday: Int?,
        repeats: Bool = true
    ) -> UNNotificationRequest {
        let content = UNMutableNotificationContent()
        var components = DateComponents()
        components.hour = hour
        components.minute = minute
        components.weekday = weekday
        let trigger = UNCalendarNotificationTrigger(
            dateMatching: components,
            repeats: repeats
        )
        return UNNotificationRequest(
            identifier: identifier,
            content: content,
            trigger: trigger
        )
    }

    @Test func identifierSchemeEncodesAlarmAndOccurrence() {
        let alarm = Alarm(label: "A", hour: 7, minute: 30)
        let daily = IOSAlarmScheduler.identifier(for: alarm, weekday: nil)
        let monday = IOSAlarmScheduler.identifier(for: alarm, weekday: 2)

        #expect(daily.hasPrefix(IOSAlarmScheduler.identifierPrefix))
        #expect(daily.contains(alarm.id.uuidString))
        #expect(daily.hasSuffix(".daily"))
        #expect(monday.hasSuffix(".wd2"))
        #expect(IOSAlarmScheduler.alarmID(fromIdentifier: monday) == alarm.id)
    }

    @Test func dailyAlarmProducesSingleRepeatingTrigger() {
        let alarm = Alarm(hour: 7, minute: 30)
        let desired = IOSAlarmScheduler.desiredRequests(for: [alarm])

        #expect(desired.count == 1)
        let trigger = desired[IOSAlarmScheduler.identifier(for: alarm, weekday: nil)]
        #expect(trigger?.dateComponents.hour == 7)
        #expect(trigger?.dateComponents.minute == 30)
        #expect(trigger?.dateComponents.weekday == nil)
        #expect(trigger?.repeats == true)
    }

    @Test func weekdayAlarmProducesOneTriggerPerWeekday() {
        let alarm = Alarm(hour: 6, minute: 0, weekdays: [2, 4, 6])
        let desired = IOSAlarmScheduler.desiredRequests(for: [alarm])

        #expect(desired.count == 3)
        for weekday in [2, 4, 6] {
            let trigger = desired[IOSAlarmScheduler.identifier(for: alarm, weekday: weekday)]
            #expect(trigger?.dateComponents.weekday == weekday)
        }
    }

    @Test func syncRemovesRequestsOfDisabledAndDeletedAlarms() async {
        let enabled = Alarm(hour: 7, minute: 0)
        let disabled = Alarm(hour: 8, minute: 0, isEnabled: false)
        let mock = MockNotificationScheduling()

        // Seed pending requests as if both alarms had been enabled before.
        let scheduler = IOSAlarmScheduler(center: mock)
        await scheduler.sync(alarms: [enabled, Alarm(id: disabled.id, hour: 8, minute: 0, isEnabled: true)])

        await scheduler.sync(alarms: [enabled, disabled])

        let pending = await mock.pendingRequests().map(\.identifier)
        #expect(pending.contains(IOSAlarmScheduler.identifier(for: enabled, weekday: nil)))
        #expect(!pending.contains(IOSAlarmScheduler.identifier(for: disabled, weekday: nil)))
    }

    @Test func syncReplacesRequestWhenTimeChanges() async {
        let original = Alarm(hour: 7, minute: 0)
        let mock = MockNotificationScheduling()
        let scheduler = IOSAlarmScheduler(center: mock)

        await scheduler.sync(alarms: [original])

        var edited = original
        edited.hour = 9
        edited.minute = 15
        await scheduler.sync(alarms: [edited])

        let pending = await mock.pendingRequests()
        let identifier = IOSAlarmScheduler.identifier(for: original, weekday: nil)
        #expect(pending.count == 1)
        let trigger = pending.first { $0.identifier == identifier }?.trigger
            as? UNCalendarNotificationTrigger
        #expect(trigger?.dateComponents.hour == 9)
        #expect(trigger?.dateComponents.minute == 15)
    }

    @Test func syncIsIdempotentForUnchangedAlarms() async throws {
        let alarm = Alarm(hour: 7, minute: 0)
        let mock = MockNotificationScheduling()
        let scheduler = IOSAlarmScheduler(center: mock)

        await scheduler.sync(alarms: [alarm])
        let addsAfterFirst = await mock.pendingRequests().count
        #expect(addsAfterFirst == 1)

        await scheduler.sync(alarms: [alarm])
        let pending = await mock.pendingRequests()
        #expect(pending.count == 1)
    }
}
#endif
