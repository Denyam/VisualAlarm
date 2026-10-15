/**
 * File: AgentAlarmSync.swift
 * Created: 2026-10-15
 *
 * Mirrors the app's alarm list to the agent XPC service.
 */

#if os(macOS)
import Combine
import Foundation

/// Seam for pushing the alarm list to the agent (mocked in tests).
@MainActor
protocol AgentAlarmSyncing {
    /// Replace the agent's stored list with `alarms` (fire-and-forget).
    func sync(_ alarms: [Alarm])
}

extension AgentXPCClient: AgentAlarmSyncing {}

/// The agent owns alarm storage: it persists `alarms.json` in its own
/// sandbox container and schedules from that copy. The app therefore hands
/// its full list to the agent once at launch (the store's initial load)
/// and again after every mutation — a full replacement keeps the two
/// copies drift-free without replaying individual edits.
@MainActor
final class AgentAlarmSync {
    private let client: any AgentAlarmSyncing
    private var cancellable: AnyCancellable?

    init(store: AlarmStore, client: (any AgentAlarmSyncing)? = nil) {
        let client = client ?? AgentXPCClient()
        self.client = client
        // Initial push covers the launch-time load…
        client.sync(store.alarms)
        // …the sink covers every subsequent mutation of the store. @Published
        // also replays the current value to this subscriber, so the agent may
        // receive one duplicate push — `replaceAll`'s equality guard turns
        // that into a no-op.
        cancellable = store.$alarms.sink { alarms in
            Task { @MainActor in client.sync(alarms) }
        }
    }
}
#endif
