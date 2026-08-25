/**
 * File: AgentStatusBanner.swift
 * Created: 2026-08-24
 */

#if os(macOS)
import SwiftUI

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
