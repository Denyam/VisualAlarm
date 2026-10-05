/**
 * File: AlarmEditorView.swift
 * Created: 2026-08-24
 */

import SwiftUI

struct AlarmEditorView: View {
    @ObservedObject var model: AlarmEditorModel
    // `presentationMode` works at both floors (dismiss needs macOS 12).
    @Environment(\.presentationMode) private var presentationMode

    var body: some View {
        NavigationView {
            Form {
                Section(header: Text("Alarm")) {
                    // No `prompt:` (macOS 12+); the placeholder carries the hint.
                    TextField("e.g. Wake up", text: $model.label)
                    DatePicker(
                        "Time",
                        selection: $model.time,
                        displayedComponents: .hourAndMinute
                    )
                    Toggle("Enabled", isOn: $model.isEnabled)
                }
                Section(header: Text("Repeat")) {
                    WeekdayChips(selection: $model.weekdays)
                }
            }
            .vaNavigationTitle(model.isEditingExisting ? "Edit Alarm" : "New Alarm")
            .vaToolbarItem(
                placement: .cancellationAction,
                fallbackAlignment: .topLeading
            ) {
                Button("Cancel") { presentationMode.wrappedValue.dismiss() }
            }
            .vaToolbarItem(placement: .confirmationAction) {
                Button("Save") {
                    model.save()
                    presentationMode.wrappedValue.dismiss()
                }
            }
        }
        #if os(macOS)
        .frame(minWidth: 380, minHeight: 280)
        #endif
    }
}
