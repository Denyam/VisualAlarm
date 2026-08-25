import SwiftUI
import UserNotifications

struct ContentView: View {
    @ObservedObject private var store = AlarmStore.shared
    @State private var editorTarget: EditorTarget?
    #if os(iOS)
    @StateObject private var coordinator = AlarmEffectCoordinator()
    private let scheduler = IOSAlarmScheduler()
    #endif

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
            #if os(iOS)
            .overlay {
                if let alarm = coordinator.firingAlarm {
                    AlarmFiringOverlay(
                        label: alarm.label,
                        onStop: { coordinator.stop() }
                    )
                }
            }
            .task {
                await requestNotificationPermission()
                await scheduler.sync(alarms: store.alarms)
                NotificationDelegate.shared.coordinator = coordinator
                NotificationDelegate.shared.alarmLookup = { [store] in store.alarms }
                UNUserNotificationCenter.current().delegate = NotificationDelegate.shared
            }
            .onChange(of: store.alarms) { _, newAlarms in
                Task { await scheduler.sync(alarms: newAlarms) }
            }
            #endif
        }
    }

    #if os(iOS)
    private func requestNotificationPermission() async {
        let center = UNUserNotificationCenter.current()
        _ = await center.requestAuthorizationIfNeeded()
    }
    #endif

    private struct EditorTarget: Identifiable {
        let id = UUID()
        let alarm: Alarm?
    }
}
