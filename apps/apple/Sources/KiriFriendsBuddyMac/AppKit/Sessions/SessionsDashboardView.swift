// SessionsDashboardView.swift
// Larger inspector view for tracked sessions. Phase 7 ships a read-only
// dashboard powered by the buddy state store; richer features (session
// alias edit, terminal focus, recent event log) follow in later phases.

import KiriFriendsMacBuddyKit
import SwiftUI

struct SessionsDashboardView: View {
    let snapshot: MacBuddyDisplaySnapshot

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            header

            Table(snapshot.sessions) {
                TableColumn("Agent") { session in
                    Text(session.key.agent.rawValue)
                        .font(.callout.monospaced())
                }
                TableColumn("Session") { session in
                    Text(session.key.sessionId)
                        .font(.caption.monospaced())
                        .foregroundStyle(.secondary)
                }
                TableColumn("State") { session in
                    Text(session.state.rawValue)
                }
                TableColumn("Priority") { session in
                    Text("\(session.state.priority)")
                }
                TableColumn("Last Event") { session in
                    Text(session.lastEventName ?? "—")
                        .font(.caption.monospaced())
                        .foregroundStyle(.tertiary)
                }
            }
            .tableStyle(.bordered)
        }
        .padding(24)
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 12) {
                Image(systemName: "rectangle.grid.2x2")
                    .symbolRenderingMode(.hierarchical)
                Text("Sessions Dashboard")
                    .font(.title2)
                Spacer()
                Text("Display: \(snapshot.displayState.rawValue)")
                    .font(.callout)
                    .foregroundStyle(.secondary)
            }
            if snapshot.permissionLocked {
                Label("Permission bubble pending", systemImage: "hand.raised.fill")
                    .foregroundStyle(.orange)
            }
            Text("\(snapshot.sessions.count) tracked session(s)")
                .font(.footnote)
                .foregroundStyle(.secondary)
        }
    }
}
