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

    @Test func alarmStoreMutationsPostChangeNotifications() async throws {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(
            at: directory,
            withIntermediateDirectories: true
        )
        defer { try? FileManager.default.removeItem(at: directory) }

        let store = AlarmStore(directory: directory)
        let counter = CounterBox()
        let token = center.addObserver(
            for: .alarmsDidChange,
            queue: .global()
        ) {
            counter.increment()
        }
        defer { token.cancel() }

        let alarm = Alarm(label: "signal", hour: 5, minute: 5)
        store.upsert(alarm)
        try await waitForCount(counter, atLeast: 1)

        store.delete(id: alarm.id)
        try await waitForCount(counter, atLeast: 2)

        store.setEnabled(false, forID: alarm.id) // no-op delete target; still no third post expected yet
        #expect(counter.value == 2)
    }

    private func waitForCount(
        _ counter: CounterBox,
        atLeast minimum: Int,
        timeout seconds: TimeInterval = 2
    ) async throws {
        let deadline = Date().addingTimeInterval(seconds)
        while counter.value < minimum && Date() < deadline {
            try await Task.sleep(for: .milliseconds(5))
        }
        #expect(counter.value >= minimum)
    }

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
