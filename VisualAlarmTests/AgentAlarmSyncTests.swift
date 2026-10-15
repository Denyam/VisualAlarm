/**
 * File: AgentAlarmSyncTests.swift
 * Created: 2026-10-15
 */

#if os(macOS)
import Foundation
import Testing

@testable import VisualAlarm

@MainActor
struct AgentAlarmSyncTests {

    private func makeTemporaryDirectory() throws -> URL {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(
            at: directory,
            withIntermediateDirectories: true
        )
        return directory
    }

    @Test func pushesInitialLoadImmediately() async throws {
        let directory = try makeTemporaryDirectory()
        let alarm = Alarm(label: "Morning", hour: 6, minute: 45)
        try JSONEncoder().encode([alarm])
            .write(to: AlarmStore.fileURL(in: directory))
        let store = AlarmStore(directory: directory, darwin: SilentSyncNotifier())
        let client = MockAgentAlarmSync()

        _ = AgentAlarmSync(store: store, client: client)

        var attempts = 0
        while client.received.first == nil && attempts < 200 {
            await Task.yield()
            attempts += 1
        }
        // The sync pushes the launch-time load before subscribing.
        #expect(client.received.first == [alarm])
    }

    @Test func pushesFullListAfterEveryMutation() async throws {
        let directory = try makeTemporaryDirectory()
        let store = AlarmStore(directory: directory, darwin: SilentSyncNotifier())
        let client = MockAgentAlarmSync()
        let sync = AgentAlarmSync(store: store, client: client)

        var attempts = 0
        while client.received.isEmpty && attempts < 200 {
            await Task.yield()
            attempts += 1
        }
        #expect(client.received.first == [])

        let alarm = Alarm(label: "A", hour: 6, minute: 0)
        store.upsert(alarm)
        attempts = 0
        while !client.received.contains([alarm]) && attempts < 200 {
            await Task.yield()
            attempts += 1
        }
        #expect(client.received.contains([alarm]))

        store.delete(id: alarm.id)
        attempts = 0
        while client.received.last != [] && attempts < 200 {
            await Task.yield()
            attempts += 1
        }
        #expect(client.received.last == [])

        // Keep the sync alive until all pushes have landed.
        withExtendedLifetime(sync) {}
    }
}

private final class MockAgentAlarmSync: AgentAlarmSyncing {
    private(set) var received: [[Alarm]] = []
    func sync(_ alarms: [Alarm]) { received.append(alarms) }
}

private final class SilentSyncNotifier: AlarmChangeSignaling {
    func post(_ notification: DarwinNotification) {}
}
#endif
