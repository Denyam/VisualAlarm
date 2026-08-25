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
