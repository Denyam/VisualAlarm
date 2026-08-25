/**
 * File: AlarmSchedulerTests.swift
 * Created: 2026-08-23
 */

import Foundation
import Testing

@testable import VisualAlarm

struct AlarmSchedulerTests {

    /// Mutable wall clock shared between the test and the scheduler.
    final class FakeClock: @unchecked Sendable {
        private let lock = NSLock()
        private var current: Date

        init(start: Date) {
            current = start
        }

        var now: Date {
            lock.lock()
            defer { lock.unlock() }
            return current
        }

        func advance(by seconds: TimeInterval) {
            lock.lock()
            current = current.addingTimeInterval(seconds)
            lock.unlock()
        }
    }

    private let epoch: Date
    private let calendar: Calendar

    init() {
        // Fixed reference: Saturday 2026-08-22 12:00 Berlin.
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "Europe/Berlin")!
        self.calendar = calendar
        epoch = calendar.date(
            from: DateComponents(year: 2026, month: 8, day: 22, hour: 12)
        )!
    }

    @Test func firesAlarmThatComesDueWithinGrace() async throws {
        let directory = try TemporaryDirectory()
        defer { try? FileManager.default.removeItem(at: directory.url) }

        let dueAt = epoch.addingTimeInterval(10) // within 60 s grace at start
        let store = AlarmStore(directory: directory.url, darwin: SilentNotifier())
        store.upsert(Alarm(label: "soon", hour: hour(of: dueAt), minute: minute(of: dueAt)))

        let clock = FakeClock(start: epoch)
        let fired = FiredBox()
        let scheduler = AlarmScheduler(
            alarms: { store.alarms },
            now: { clock.now },
            calendar: calendar,
            onFire: { fired.append($0) }
        )

        await scheduler.step { _ in }

        #expect(fired.count == 1)

        await scheduler.step { _ in }
        #expect(fired.count == 1) // not re-fired; cursor consumed the instant
    }

    @Test func skipsAlarmsStaleBeyondGrace() async throws {
        let directory = try TemporaryDirectory()
        defer { try? FileManager.default.removeItem(at: directory.url) }

        // Alarm was due an hour before the scheduler starts.
        let staleTime = epoch.addingTimeInterval(-3_600)
        let store = AlarmStore(directory: directory.url, darwin: SilentNotifier())
        store.upsert(Alarm(label: "stale", hour: hour(of: staleTime), minute: minute(of: staleTime)))

        let clock = FakeClock(start: epoch)
        let fired = FiredBox()
        let slept = SleepRecorder()
        let scheduler = AlarmScheduler(
            alarms: { store.alarms },
            now: { clock.now },
            calendar: calendar,
            maxChunk: 30,
            onFire: { fired.append($0) }
        )

        await scheduler.step { duration in
            slept.record(duration)
            clock.advance(by: Double(duration.components.seconds))
        }

        #expect(fired.count == 0)
        #expect(slept.durations.first == 30) // sleeps toward tomorrow's occurrence, capped
    }

    @Test func waitsInCappedChunksUntilDueThenFires() async throws {
        let directory = try TemporaryDirectory()
        defer { try? FileManager.default.removeItem(at: directory.url) }

        // One full minute out (alarms have minute granularity).
        let dueAt = epoch.addingTimeInterval(60)
        let store = AlarmStore(directory: directory.url, darwin: SilentNotifier())
        store.upsert(Alarm(label: "later", hour: hour(of: dueAt), minute: minute(of: dueAt)))

        let clock = FakeClock(start: epoch)
        let fired = FiredBox()
        let slept = SleepRecorder()
        let scheduler = AlarmScheduler(
            alarms: { store.alarms },
            now: { clock.now },
            calendar: calendar,
            maxChunk: 30,
            onFire: { fired.append($0) }
        )

        for _ in 0..<4 where fired.count == 0 {
            await scheduler.step { duration in
                slept.record(duration)
                clock.advance(by: Double(duration.components.seconds))
            }
        }

        #expect(fired.count == 1)
        #expect(slept.durations == [30, 30]) // capped chunk twice, then due
    }

    @Test func picksUpNewlyAddedAlarmsOnNextStep() async throws {
        let directory = try TemporaryDirectory()
        defer { try? FileManager.default.removeItem(at: directory.url) }

        let store = AlarmStore(directory: directory.url, darwin: SilentNotifier())
        let clock = FakeClock(start: epoch)
        let fired = FiredBox()
        let scheduler = AlarmScheduler(
            alarms: { store.alarms },
            now: { clock.now },
            calendar: calendar,
            onFire: { fired.append($0) }
        )

        // No alarms yet: idle sleep of a full chunk.
        await scheduler.step { _ in clock.advance(by: 30) }
        #expect(fired.count == 0)

        // Add an alarm due right now-ish; next step must fire it.
        let dueAt = clock.now.addingTimeInterval(5)
        store.upsert(Alarm(label: "added", hour: hour(of: dueAt), minute: minute(of: dueAt)))

        await scheduler.step { _ in clock.advance(by: 5) }
        #expect(fired.count == 1)
    }

    @Test func disabledAlarmsNeverFire() async throws {
        let directory = try TemporaryDirectory()
        defer { try? FileManager.default.removeItem(at: directory.url) }

        let store = AlarmStore(directory: directory.url, darwin: SilentNotifier())
        store.upsert(Alarm(hour: 12, minute: 0, isEnabled: false))

        let clock = FakeClock(start: epoch)
        let fired = FiredBox()
        let scheduler = AlarmScheduler(
            alarms: { store.alarms },
            now: { clock.now },
            calendar: calendar,
            onFire: { fired.append($0) }
        )

        for _ in 0..<3 {
            await scheduler.step { _ in clock.advance(by: 30 * 60) }
        }

        #expect(fired.count == 0)
    }

    // MARK: - Helpers

    private func hour(of date: Date) -> Int {
        calendar.component(.hour, from: date)
    }

    private func minute(of date: Date) -> Int {
        calendar.component(.minute, from: date)
    }
}

private struct TemporaryDirectory {
    let url: URL

    init() throws {
        url = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(
            at: url,
            withIntermediateDirectories: true
        )
    }
}

private final class FiredBox: @unchecked Sendable {
    private let lock = NSLock()
    private var items: [Alarm] = []

    var count: Int {
        lock.lock()
        defer { lock.unlock() }
        return items.count
    }

    func append(_ alarm: Alarm) {
        lock.lock()
        items.append(alarm)
        lock.unlock()
    }
}

private final class SleepRecorder: @unchecked Sendable {
    private let lock = NSLock()
    private(set) var durations: [Double] = []

    func record(_ duration: Duration) {
        lock.lock()
        durations.append(Double(duration.components.seconds))
        lock.unlock()
    }
}

private final class SilentNotifier: AlarmChangeSignaling {
    func post(_ notification: DarwinNotification) {}
}
