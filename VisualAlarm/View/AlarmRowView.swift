/**
 * File: AlarmRowView.swift
 * Created: 2026-08-24
 */

import Combine
import SwiftUI

struct AlarmRowView: View {
    let alarm: Alarm
    let setEnabled: (Bool) -> Void
    let onEdit: () -> Void

    @State private var now = Date()

    private static let clockTick = Timer.publish(every: 30, on: .main, in: .common)
        .autoconnect()

    var body: some View {
        HStack(spacing: 12) {
            Text(String(format: "%02d:%02d", alarm.hour, alarm.minute))
                .font(.system(.title2, design: .rounded).weight(.semibold))
                .foregroundStyle(alarm.isEnabled ? .primary : .secondary)

            VStack(alignment: .leading, spacing: 2) {
                Text(alarm.label.isEmpty ? "Alarm" : alarm.label)
                    .font(.headline)
                Text(NextFirePreview.text(for: alarm, now: now) ?? "Never")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .contentShape(Rectangle())
            .onTapGesture(perform: onEdit)

            Spacer()

            #if os(macOS)
            Button("Test") {
                WorkspaceRunnerLauncher().launch(firingAlarm: alarm)
            }
            .buttonStyle(.bordered)
            #endif

            Toggle("", isOn: Binding(get: { alarm.isEnabled }, set: setEnabled))
                .labelsHidden()
        }
        .padding(.vertical, 2)
        .onReceive(Self.clockTick) { tick in
            now = tick
        }
    }
}
