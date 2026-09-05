/**
 * File: AlarmFiringOverlay.swift
 * Created: 2026-08-25
 */

#if os(iOS)
import SwiftUI

/// Full-screen overlay shown while an alarm effect is running.
/// Displays the alarm label and a prominent Stop button.
struct AlarmFiringOverlay: View {
    let label: String
    let onStop: () -> Void

    @State private var appeared = false

    var body: some View {
        ZStack {
            Color.black.opacity(0.85)
                .ignoresSafeArea()

            VStack(spacing: 32) {
                Image(systemName: "alarm.fill")
                    .font(.system(size: 64))
                    .foregroundStyle(.red)

                Text(label.isEmpty ? "Alarm" : label)
                    .font(.largeTitle.bold())
                    .foregroundStyle(.white)

                Button(action: onStop) {
                    Text("Stop")
                        .font(.title.bold())
                        .foregroundStyle(.white)
                        .frame(width: 200, height: 56)
                        .background(.red, in: RoundedRectangle(cornerRadius: 16))
                }
            }
        }
        .transition(.opacity)
        .animation(.easeInOut, value: appeared)
    }
}
#endif
