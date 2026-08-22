/**
 * File: DarwinNotificationCenter.swift
 * Created: 2026-08-22
 */

import Foundation

/// Cross-process notifications delivered through the Darwin notify center.
/// Darwin notifications carry no payload — observers re-read shared state
/// (e.g. `AlarmStore`) when they arrive.
enum DarwinNotification: String {
    /// Some process changed `alarms.json`; others should reload it.
    case alarmsDidChange = "co.denis.VisualAlarm.alarms.didChange"
    /// The agent is about to launch the runner for a due alarm.
    case alarmShouldFire = "co.denis.VisualAlarm.alarm.shouldFire"
}

/// Removes its underlying observer when cancelled or deallocated.
final class DarwinObservationToken {
    private let center: CFNotificationCenter
    private let name: CFNotificationName
    private let queue: DispatchQueue
    private let block: () -> Void

    fileprivate init(
        center: CFNotificationCenter,
        name: CFNotificationName,
        queue: DispatchQueue,
        block: @escaping () -> Void
    ) {
        self.center = center
        self.name = name
        self.queue = queue
        self.block = block
    }

    func cancel() {
        CFNotificationCenterRemoveObserver(
            center,
            rawObserverPointer,
            name,
            nil
        )
    }

    deinit {
        cancel()
    }

    fileprivate var rawObserverPointer: UnsafeMutableRawPointer {
        UnsafeMutableRawPointer(Unmanaged.passUnretained(self).toOpaque())
    }

    fileprivate func deliver() {
        queue.async(execute: block)
    }
}

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
