/**
 * File: NotificationDelegate.swift
 * Created: 2026-08-25
 */

#if os(iOS)
import UserNotifications

/// Bridges `UNUserNotificationCenterDelegate` events into the
/// `AlarmEffectCoordinator` so foreground banners and notification taps
/// both trigger the visual alarm.
@MainActor
final class NotificationDelegate: NSObject, UNUserNotificationCenterDelegate {
    static let shared = NotificationDelegate()

    var coordinator: AlarmEffectCoordinator?
    var alarmLookup: () -> [Alarm] = { [] }

    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification
    ) async -> UNNotificationPresentationOptions {
        await activateEffect(for: notification.request.identifier)
        return []
    }

    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse
    ) async {
        await activateEffect(for: response.notification.request.identifier)
    }

    private func activateEffect(for identifier: String) async {
        guard let alarmID = IOSAlarmScheduler.alarmID(fromIdentifier: identifier),
              let alarm = alarmLookup().first(where: { $0.id == alarmID })
        else { return }
        await coordinator?.start(for: alarm)
    }
}
#endif
