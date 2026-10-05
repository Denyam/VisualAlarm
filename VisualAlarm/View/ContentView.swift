import SwiftUI
import UserNotifications
import Combine

struct ContentView: View {
    @ObservedObject private var store = AlarmStore.shared
    @State private var editorTarget: EditorTarget?
    @State private var hasAppeared = false
    @State private var now = Date()
    
    private static let clockTick = Timer.publish(every: 30, on: .main, in: .common)
        .autoconnect()
    
    #if os(iOS)
    @StateObject private var coordinator = AlarmEffectCoordinator()
    private let scheduler = IOSAlarmScheduler()
    #endif

    var body: some View {
        NavigationView {
            Group {
                if store.alarms.isEmpty {
                    VAContentUnavailableView(
                        title: "No alarms",
                        systemImage: "alarm",
                        message: "Add one to get started."
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
                                },
                                now: now
                            )
                            .contextMenu {
                                Button("Edit…") {
                                    editorTarget = EditorTarget(alarm: alarm)
                                }
                                Divider()
                                deleteButton(for: alarm)
                            }
                        }
                        .onDelete { store.delete(atOffsets: $0) }
                    }
                }
            }
            .vaNavigationTitle("Alarms")
            // Toolbar before the banner inset: on the macOS 10.15 fallback
            // path the "+" overlays the list below the banner row.
            .vaToolbarItem(placement: .primaryAction) {
                Button {
                    editorTarget = EditorTarget(alarm: nil)
                } label: {
                    VASymbolImage(systemName: "plus", fallback: "+")
                }
            }
            #if os(macOS)
            .vaSafeAreaInset(edge: .top, spacing: 0) {
                AgentStatusBanner()
            }
            #endif
            .sheet(item: $editorTarget) { target in
                AlarmEditorView(
                    model: AlarmEditorModel(alarm: target.alarm) { alarm in
                        store.upsert(alarm)
                    }
                )
            }
            .onReceive(Self.clockTick) { tick in
                now = tick
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
                hasAppeared = true
            }
            .onChange(of: store.alarms) { newAlarms in
                guard hasAppeared else { return }
                Task { await scheduler.sync(alarms: newAlarms) }
            }
            #endif
        }
        #if os(iOS)
        // Keep the single-column stack layout NavigationStack had (iPad
        // otherwise renders a two-column browser); macOS NavigationView is
        // stack-only and has no StackNavigationViewStyle.
        .navigationViewStyle(StackNavigationViewStyle())
        #endif
    }

    @ViewBuilder
    private func deleteButton(for alarm: Alarm) -> some View {
        #if os(macOS)
        // `Button(role:)` needs macOS 12; 10.15–11 use a plain delete.
        if #available(macOS 12.0, *) {
            Button("Delete", role: .destructive) {
                store.delete(id: alarm.id)
            }
        } else {
            Button("Delete") {
                store.delete(id: alarm.id)
            }
        }
        #else
        Button("Delete", role: .destructive) {
            store.delete(id: alarm.id)
        }
        #endif
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
