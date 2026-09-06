/**
 * File: AlarmStoreTests.swift
 * Created: 2026-08-22
 */

import Foundation
import Testing

@testable import VisualAlarm

@MainActor
struct AlarmStoreTests {

    private func makeTemporaryDirectory() throws -> URL {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(
            at: directory,
            withIntermediateDirectories: true
        )
        return directory
    }

    @Test func startsEmptyWhenNoFileExists() {
        let directory = (try? makeTemporaryDirectory())!
        let store = AlarmStore(directory: directory, darwin: SilentNotifier())
        #expect(store.alarms.isEmpty)
    }

    @Test func upsertAppendsAndPersistsAcrossInstances() throws {
        let directory = try makeTemporaryDirectory()
        let alarm = Alarm(label: "Morning", hour: 6, minute: 45)

        AlarmStore(directory: directory, darwin: SilentNotifier()).upsert(alarm)

        let reloaded = AlarmStore(directory: directory, darwin: SilentNotifier())
        #expect(reloaded.alarms == [alarm])
    }

    @Test func upsertReplacesExistingIdentifier() throws {
        let directory = try makeTemporaryDirectory()
        let original = Alarm(label: "A", hour: 1, minute: 1)
        let store = AlarmStore(directory: directory, darwin: SilentNotifier())
        store.upsert(original)

        var renamed = original
        renamed.label = "B"
        store.upsert(renamed)

        #expect(store.alarms == [renamed])
    }

    @Test func deleteRemovesAndPersists() throws {
        let directory = try makeTemporaryDirectory()
        let first = Alarm(hour: 1, minute: 1)
        let second = Alarm(hour: 2, minute: 2)
        let store = AlarmStore(directory: directory, darwin: SilentNotifier())
        store.upsert(first)
        store.upsert(second)

        store.delete(id: first.id)

        #expect(store.alarms == [second])
        #expect(AlarmStore(directory: directory, darwin: SilentNotifier()).alarms == [second])
    }

    @Test func deleteAtOffsetsRemovesMultipleAndPersistsOnce() throws {
        let directory = try makeTemporaryDirectory()
        let a1 = Alarm(hour: 1, minute: 1)
        let a2 = Alarm(hour: 2, minute: 2)
        let a3 = Alarm(hour: 3, minute: 3)
        let store = AlarmStore(directory: directory, darwin: SilentNotifier())
        store.upsert(a1); store.upsert(a2); store.upsert(a3)

        store.delete(atOffsets: IndexSet([0, 2]))

        #expect(store.alarms == [a2])
        #expect(AlarmStore(directory: directory, darwin: SilentNotifier()).alarms == [a2])
    }

    @Test func loadReflectsExternalFileChanges() throws {
        let directory = try makeTemporaryDirectory()
        let store = AlarmStore(directory: directory, darwin: SilentNotifier())
        let external = Alarm(label: "External", hour: 9, minute: 9)
        let data = try JSONEncoder().encode([external])

        try data.write(to: AlarmStore.fileURL(in: directory))

        #expect(store.load() == [external])
    }

    @Test func corruptedJSONFallsBackToEmptyList() throws {
        let directory = try makeTemporaryDirectory()
        try Data("not json".utf8).write(to: AlarmStore.fileURL(in: directory))

        let store = AlarmStore(directory: directory, darwin: SilentNotifier())

        #expect(store.alarms.isEmpty)
    }
}

private final class SilentNotifier: AlarmChangeSignaling {
    func post(_ notification: DarwinNotification) {}
}
