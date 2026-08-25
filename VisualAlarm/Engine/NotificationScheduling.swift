/**
 * File: NotificationScheduling.swift
 * Created: 2026-08-25
 */

#if os(iOS)
import UserNotifications

/// Seam over `UNUserNotificationCenter` so scheduler logic can be tested
/// without touching the system notification store.
protocol NotificationScheduling {
    func requestAuthorizationIfNeeded() async -> Bool
    func schedule(_ request: UNNotificationRequest) async throws
    func removePendingRequests(withIdentifiers identifiers: [String]) async
    func pendingRequests() async -> [UNNotificationRequest]
}

extension UNUserNotificationCenter: NotificationScheduling {
    func requestAuthorizationIfNeeded() async -> Bool {
        (try? await requestAuthorization(options: [.alert, .sound])) ?? false
    }

    func schedule(_ request: UNNotificationRequest) async throws {
        try await add(request)
    }

    func removePendingRequests(withIdentifiers identifiers: [String]) async {
        removePendingNotificationRequests(withIdentifiers: identifiers)
    }

    func pendingRequests() async -> [UNNotificationRequest] {
        await withCheckedContinuation { continuation in
            getPendingNotificationRequests { requests in
                continuation.resume(returning: requests)
            }
        }
    }
}
#endif
