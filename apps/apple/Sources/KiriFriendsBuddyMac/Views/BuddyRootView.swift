// BuddyRootView.swift
// Settings status surface for bridge health, bound port, and the current
// MacBuddy display state.

import KiriFriendsCore
import KiriFriendsMacBuddyKit
import SwiftUI

struct BuddyRootView: View {
    @Bindable var model: BridgeAppModel

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            header

            statusRow

            Divider()

            displayStateBlock
        }
        .padding(24)
        .frame(width: 360, height: 280)
    }

    private var header: some View {
        HStack(spacing: 12) {
            Image(systemName: "sparkles")
                .resizable()
                .scaledToFit()
                .frame(width: 32, height: 32)
                .symbolRenderingMode(.hierarchical)
            VStack(alignment: .leading) {
                Text("Kiri Buddy for macOS")
                    .font(.headline)
                Text("Schema v\(MacBuddyKit.schemaVersion)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }

    private var statusRow: some View {
        HStack(spacing: 12) {
            Circle()
                .fill(statusColor)
                .frame(width: 10, height: 10)
            Text(statusText)
                .font(.callout)
                .foregroundStyle(.primary)
        }
    }

    private var displayStateBlock: some View {
        VStack(alignment: .leading, spacing: 8) {
            LabeledContent("State", value: model.snapshot.displayState.rawValue)
            LabeledContent("Sessions", value: "\(model.snapshot.sessions.count)")
            LabeledContent("Persona", value: model.snapshot.displayState.personaProjection.rawValue)
            if model.snapshot.permissionLocked {
                LabeledContent("Permission", value: "locked")
                    .foregroundStyle(.orange)
            }
        }
        .font(.callout)
    }

    private var statusText: String {
        switch model.status {
        case .stopped: return "Bridge stopped"
        case .starting: return "Starting bridge…"
        case .running(let port): return "Listening on 127.0.0.1:\(port)"
        case .failed(let message): return "Failed: \(message)"
        }
    }

    private var statusColor: Color {
        switch model.status {
        case .stopped: return .gray
        case .starting: return .yellow
        case .running: return .green
        case .failed: return .red
        }
    }
}

#Preview {
    BuddyRootView(model: BridgeAppModel())
}
