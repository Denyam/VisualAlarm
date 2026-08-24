import Combine
import SwiftUI

struct ContentView: View {
    @ObservedObject private var store = AlarmStore.shared
    @State private var editorTarget: EditorTarget?

    var body: some View {
        NavigationStack {
            Group {
                if store.alarms.isEmpty {
                    ContentUnavailableView(
                        "No alarms",
                        systemImage: "alarm",
                        description: Text("Add one to get started.")
                    )
                } else {
                    List {
                        ForEach(store.alarms) { alarm in
                            AlarmRowView(
                                alarm: alarm,
                                setEnabled: { newValue in
                                    store.setEnabled(newValue, forID: alarm.id)
                                },
                                onEdit: {
                                    editorTarget = EditorTarget(alarm: alarm)
                                }
                            )
                            .contextMenu {
                                Button("Edit…") {
                                    editorTarget = EditorTarget(alarm: alarm)
                                }
                                Divider()
                                Button(
                                    "Delete",
                                    role: .destructive,
                                    action: { store.delete(id: alarm.id) }
                                )
                            }
                        }
                        .onDelete { store.delete(atOffsets: $0) }
                    }
                }
            }
            .navigationTitle("Alarms")
            #if os(macOS)
            .safeAreaInset(edge: .top, spacing: 0) {
                AgentStatusBanner()
            }
            #endif
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button {
                        editorTarget = EditorTarget(alarm: nil)
                    } label: {
                        Image(systemName: "plus")
                    }
                }
            }
            .sheet(item: $editorTarget) { target in
                AlarmEditorView(
                    model: AlarmEditorModel(alarm: target.alarm) { alarm in
                        store.upsert(alarm)
                    }
                )
            }
        }
    }

    private struct EditorTarget: Identifiable {
        let id = UUID()
        let alarm: Alarm?
    }
}

// MARK: - Agent status banner (macOS)

#if os(macOS)
struct AgentStatusBanner: View {
    @StateObject private var model = AgentRegistrarModel()

    var body: some View {
        HStack(spacing: 10) {
            Circle()
                .fill(color)
                .frame(width: 8, height: 8)

            Text(message)

            Spacer()

            switch model.status {
            case .enabled:
                Button("Disable") { model.unregister() }
            case .requiresApproval:
                Button("Open Login Items Settings") { model.openLoginItemsSettings() }
            default:
                Button("Enable Scheduler") { model.register() }
            }
        }
        .font(.callout)
        .padding(.horizontal)
        .padding(.vertical, 6)
        .background(.bar)
        .onAppear { model.refresh() }
    }

    private var color: Color {
        switch model.status {
        case .enabled: return .green
        case .requiresApproval: return .orange
        default: return .secondary
        }
    }

    private var message: String {
        switch model.status {
        case .enabled:
            return "Background scheduler active"
        case .requiresApproval:
            return "Approve the scheduler in System Settings › Login Items"
        default:
            return "Background scheduler is off — alarms fire only while this app runs"
        }
    }
}
#endif

// MARK: - Row

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

// MARK: - Editor sheet

struct AlarmEditorView: View {
    @ObservedObject var model: AlarmEditorModel
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            Form {
                Section("Alarm") {
                    TextField(
                        "Label",
                        text: $model.label,
                        prompt: Text("e.g. Wake up")
                    )
                    DatePicker(
                        "Time",
                        selection: $model.time,
                        displayedComponents: .hourAndMinute
                    )
                    Toggle("Enabled", isOn: $model.isEnabled)
                }
                Section("Repeat") {
                    WeekdayChips(selection: $model.weekdays)
                }
            }
            .navigationTitle(model.isEditingExisting ? "Edit Alarm" : "New Alarm")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        model.save()
                        dismiss()
                    }
                }
            }
        }
        #if os(macOS)
        .frame(minWidth: 380, minHeight: 280)
        #endif
    }
}

// MARK: - Weekday chips

struct WeekdayChips: View {
    @Binding var selection: Set<Int>

    /// Monday-first presentation; values match `Calendar.weekday`.
    private static let displayOrder: [(value: Int, letter: String)] = [
        (2, "M"), (3, "T"), (4, "W"), (5, "T"), (6, "F"), (7, "S"), (1, "S"),
    ]

    var body: some View {
        HStack(spacing: 8) {
            ForEach(Self.displayOrder, id: \.value) { entry in
                let isOn = selection.contains(entry.value)
                Button {
                    if isOn {
                        selection.remove(entry.value)
                    } else {
                        selection.insert(entry.value)
                    }
                } label: {
                    Text(entry.letter)
                        .font(.footnote.weight(.semibold))
                        .frame(width: 30, height: 30)
                }
                .buttonStyle(.bordered)
                .tint(isOn ? .accentColor : .secondary)
                .opacity(isOn ? 1 : 0.6)
            }
        }
    }
}
