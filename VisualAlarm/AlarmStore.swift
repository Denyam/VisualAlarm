/**
 * File: AlarmStore.swift
 * Created: 2026-08-22
 */

import Combine
import Foundation
import OSLog

enum AppGroup {
    static let identifier = "co.denis.VisualAlarm.shared"
    static let alarmsFilename = "alarms.json"

    static var containerURL: URL? {
        FileManager.default.containerURL(
            forSecurityApplicationGroupIdentifier: identifier
        )
    }

    /// Directory shared by app, agent, and runner; falls back to Application
    /// Support when no container is available (unsandboxed tools, tests).
    static var directory: URL {
        if let container = containerURL {
            return container
        }
        let fallback = FileManager.default.urls(
            for: .applicationSupportDirectory,
            in: .userDomainMask
        )[0].appendingPathComponent("VisualAlarm", isDirectory: true)
        try? FileManager.default.createDirectory(
            at: fallback,
            withIntermediateDirectories: true
        )
        return fallback
    }
}

/// Owns the alarm list and persists it as JSON inside a shared directory so
/// that the app, agent, and runner processes observe the same state.
final class AlarmStore: ObservableObject {
    static let shared = AlarmStore()

    private static let logger = Logger(
        subsystem: "co.denis.VisualAlarm",
        category: "store"
    )

    @Published private(set) var alarms: [Alarm] = []

    private let fileURL: URL

    /// - Parameter directory: Directory holding `alarms.json`.
    ///   Defaults to the App Group container with an Application Support fallback.
    init(directory: URL? = nil) {
        let resolved = directory ?? AppGroup.directory
        fileURL = resolved.appendingPathComponent(AppGroup.alarmsFilename)
        load()
    }

    static func fileURL(in directory: URL) -> URL {
        directory.appendingPathComponent(AppGroup.alarmsFilename)
    }

    @discardableResult
    func load() -> [Alarm] {
        guard let data = try? Data(contentsOf: fileURL) else {
            alarms = []
            return alarms
        }
        do {
            alarms = try JSONDecoder().decode([Alarm].self, from: data)
        } catch {
            Self.logger.error("Decoding \(self.fileURL.path) failed: \(error.localizedDescription)")
            alarms = []
        }
        return alarms
    }

    func upsert(_ alarm: Alarm) {
        if let index = alarms.firstIndex(where: { $0.id == alarm.id }) {
            alarms[index] = alarm
        } else {
            alarms.append(alarm)
        }
        persist()
    }

    func delete(id: UUID) {
        alarms.removeAll { $0.id == id }
        persist()
    }

    private func persist() {
        do {
            let data = try JSONEncoder().encode(alarms)
            try data.write(to: fileURL, options: .atomic)
        } catch {
            Self.logger.error("Persisting alarms failed: \(error.localizedDescription)")
        }
    }
}
