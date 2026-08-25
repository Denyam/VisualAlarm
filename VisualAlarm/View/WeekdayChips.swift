/**
 * File: WeekdayChips.swift
 * Created: 2026-08-24
 */

import SwiftUI

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
