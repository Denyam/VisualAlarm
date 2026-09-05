/**
 * File: AlarmStore.swift
 * Created: 2026-08-22
 */

import Combine
import Foundation
import OSLog

/// Owns the alarm list and persists it as JSON inside a shared directory so
/// that the app, agent, and runner processes observe the same state.
@MainActor
final class AlarmStore: ObservableObject {
    static let shared = AlarmStore()

    private static let logger = Logger(
        subsystem: "co.denis.VisualAlarm",
        category: "store"
    )

    @Published private(set) var alarms: [Alarm] = []

    private let fileURL: URL
    private let darwin: any AlarmChangeSignaling

    /// - Parameters:
    ///   - directory: Directory holding `alarms.json`.
    ///     Defaults to the App Group container with an Application Support fallback.
    ///   - darwin: Change-signal center; every successful mutation posts
    ///     `.alarmsDidChange` so resident agents reload immediately.
    init(
        directory: URL? = nil,
        darwin: any AlarmChangeSignaling = DarwinNotificationCenter.shared
    ) {
        let resolved = directory ?? AppGroup.directory
        fileURL = resolved.appendingPathComponent(AppGroup.alarmsFilename)
        self.darwin = darwin
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

    func delete(atOffsets offsets: IndexSet) {
        let ids = offsets
            .compactMap { index -> UUID? in
                alarms.indices.contains(index) ? alarms[index].id : nil
            }
        ids.forEach { delete(id: $0) }
    }

    /// Enables or disables the alarm with the given identifier.
    func setEnabled(_ enabled: Bool, forID id: UUID) {
        guard let index = alarms.firstIndex(where: { $0.id == id }) else { return }
        alarms[index].isEnabled = enabled
        persist()
    }

    private func persist() {
        do {
            let data = try JSONEncoder().encode(alarms)
            try data.write(to: fileURL, options: .atomic)
            // Tell resident agents (and other windows) to reload.
            darwin.post(.alarmsDidChange)
        } catch {
            Self.logger.error("Persisting alarms failed: \(error.localizedDescription)")
        }
    }
}
