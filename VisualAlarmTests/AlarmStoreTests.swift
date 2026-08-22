/**
 * File: AlarmStoreTests.swift
 * Created: 2026-08-22
 */

import Foundation
import Testing

@testable import VisualAlarm

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
        let store = AlarmStore(directory: directory)
        #expect(store.alarms.isEmpty)
    }

    @Test func upsertAppendsAndPersistsAcrossInstances() throws {
        let directory = try makeTemporaryDirectory()
        let alarm = Alarm(label: "Morning", hour: 6, minute: 45)

        AlarmStore(directory: directory).upsert(alarm)

        let reloaded = AlarmStore(directory: directory)
        #expect(reloaded.alarms == [alarm])
    }

    @Test func upsertReplacesExistingIdentifier() throws {
        let directory = try makeTemporaryDirectory()
        let original = Alarm(label: "A", hour: 1, minute: 1)
        let store = AlarmStore(directory: directory)
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
        let store = AlarmStore(directory: directory)
        store.upsert(first)
        store.upsert(second)

        store.delete(id: first.id)

        #expect(store.alarms == [second])
        #expect(AlarmStore(directory: directory).alarms == [second])
    }

    @Test func loadReflectsExternalFileChanges() throws {
        let directory = try makeTemporaryDirectory()
        let store = AlarmStore(directory: directory)
        let external = Alarm(label: "External", hour: 9, minute: 9)
        let data = try JSONEncoder().encode([external])

        try data.write(to: AlarmStore.fileURL(in: directory))

        #expect(store.load() == [external])
    }

    @Test func corruptedJSONFallsBackToEmptyList() throws {
        let directory = try makeTemporaryDirectory()
        try Data("not json".utf8).write(to: AlarmStore.fileURL(in: directory))

        let store = AlarmStore(directory: directory)

        #expect(store.alarms.isEmpty)
    }
}
