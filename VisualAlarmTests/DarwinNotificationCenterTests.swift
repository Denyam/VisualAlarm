/**
 * File: DarwinNotificationCenterTests.swift
 * Created: 2026-08-22
 */

import Foundation
import Testing

@testable import VisualAlarm

@Suite(.serialized)
struct DarwinNotificationCenterTests {

    private let center = DarwinNotificationCenter.shared

    @Test func observerReceivesPostedNotification() async throws {
        let counter = CounterBox()
        let token = center.addObserver(
            for: .alarmsDidChange,
            queue: .global()
        ) {
            counter.increment()
        }
        defer { token.cancel() }

        center.post(.alarmsDidChange)

        let deadline = Date().addingTimeInterval(2)
        while counter.value == 0 && Date() < deadline {
            try await Task.sleep(for: .milliseconds(10))
        }

        #expect(counter.value >= 1)
    }

    @Test func cancelledObserverStopsReceivingNotifications() async throws {
        let counter = CounterBox()
        let token = center.addObserver(
            for: .alarmShouldFire,
            queue: .global()
        ) {
            counter.increment()
        }
        token.cancel()

        center.post(.alarmShouldFire)
        try await Task.sleep(for: .milliseconds(200))

        #expect(counter.value == 0)
    }

    @Test func tokenDeallocationRemovesObserver() async throws {
        var token: DarwinObservationToken? = nil
        let counter = CounterBox()
        token = center.addObserver(
            for: .alarmsDidChange,
            queue: .global()
        ) {
            counter.increment()
        }
        token = nil

        center.post(.alarmsDidChange)
        try await Task.sleep(for: .milliseconds(200))

        #expect(counter.value == 0)
    }
}

private final class CounterBox: @unchecked Sendable {
    private let lock = NSLock()
    private(set) var value = 0

    func increment() {
        lock.lock()
        value += 1
        lock.unlock()
    }
}
