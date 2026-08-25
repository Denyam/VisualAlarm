/**
 * File: FireRequest.swift
 * Created: 2026-08-23
 */

import Foundation

/// Snapshot of the alarm that is currently ringing, handed from the agent to
/// the runner through the shared container so the stop window can describe it.
struct FireRequest: Codable, Equatable {
    let alarmID: UUID
    let label: String
    let firedAt: Date

    static let filename = "fire-request.json"

    static func write(
        _ request: FireRequest,
        directory: URL? = nil
    ) throws {
        let resolved = directory ?? AppGroup.directory
        let data = try JSONEncoder().encode(request)
        try data.write(
            to: resolved.appendingPathComponent(filename),
            options: .atomic
        )
    }

    static func read(directory: URL? = nil) -> FireRequest? {
        let resolved = directory ?? AppGroup.directory
        guard let data = try? Data(
            contentsOf: resolved.appendingPathComponent(filename)
        ) else { return nil }
        return try? JSONDecoder().decode(FireRequest.self, from: data)
    }
}
