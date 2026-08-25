/**
 * File: AlarmEditorView.swift
 * Created: 2026-08-24
 */

import SwiftUI

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
