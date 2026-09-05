import Foundation

private func darwinCallback(
    _ center: CFNotificationCenter?,
    _ observer: UnsafeMutableRawPointer?,
    _ name: CFNotificationName?,
    _ object: UnsafeRawPointer?,
    _ userInfo: CFDictionary?
) {
    guard let observer else { return }
    let token = Unmanaged<DarwinObservationToken>
        .fromOpaque(observer)
        .takeUnretainedValue()
    token.deliver()
}

final class DarwinNotificationCenter {
    static let shared = DarwinNotificationCenter()

    private let center = CFNotificationCenterGetDarwinNotifyCenter()!

    func post(_ notification: DarwinNotification) {
        CFNotificationCenterPostNotification(
            center,
            CFNotificationName(notification.rawValue as CFString),
            nil,
            nil,
            true
        )
    }

    @discardableResult
    func addObserver(
        for notification: DarwinNotification,
        queue: DispatchQueue = .main,
        using block: @escaping () -> Void
    ) -> DarwinObservationToken {
        let name = CFNotificationName(notification.rawValue as CFString)
        let token = DarwinObservationToken(
            center: center,
            name: name,
            queue: queue,
            block: block
        )
        CFNotificationCenterAddObserver(
            center,
            token.rawObserverPointer,
            darwinCallback,
            notification.rawValue as CFString,
            nil,
            .deliverImmediately
        )
        return token
    }
}
