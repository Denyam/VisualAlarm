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
    let now: Date

    var body: some View {
        HStack(spacing: 12) {
            Text(String(format: "%02d:%02d", alarm.hour, alarm.minute))
                .font(.system(size: 22, weight: .semibold, design: .rounded))
                .foregroundColor(alarm.isEnabled ? .primary : .secondary)

            VStack(alignment: .leading, spacing: 2) {
                Text(alarm.label.isEmpty ? "Alarm" : alarm.label)
                    .font(.headline)
                Text(NextFirePreview.text(for: alarm, now: now) ?? "Never")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            .contentShape(Rectangle())
            .onTapGesture(perform: onEdit)

            Spacer()

            #if os(macOS)
            Button("Test") {
                WorkspaceRunnerLauncher().launch(firingAlarm: alarm)
            }
            .vaBorderedButtonStyle()
            #endif

            Toggle("", isOn: Binding(get: { alarm.isEnabled }, set: setEnabled))
                .labelsHidden()
        }
        .padding(.vertical, 2)
    }
}
