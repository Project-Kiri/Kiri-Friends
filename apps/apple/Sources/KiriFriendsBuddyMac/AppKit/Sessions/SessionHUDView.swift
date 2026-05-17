// SessionHUDView.swift
// Compact SwiftUI panel that lists the live sessions the buddy is
// currently tracking. Ports
// `.workspace/reference/clawd-on-desk/src/session-hud-renderer.js` into
// SwiftUI without the click-to-focus behaviour (terminal focus is a
// later phase that needs Accessibility permissions).

import KiriFriendsMacBuddyKit
import SwiftUI

struct SessionHUDView: View {
    let sessions: [BuddySession]
    let permissionLocked: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: "rectangle.stack.fill")
                    .symbolRenderingMode(.hierarchical)
                Text("Sessions")
                    .font(.headline)
                Spacer()
                if permissionLocked {
                    Label("Pending", systemImage: "hand.raised.fill")
                        .font(.caption)
                        .foregroundStyle(.orange)
                }
            }

            if sessions.isEmpty {
                Text("No active CLI sessions.")
                    .font(.callout)
                    .foregroundStyle(.secondary)
            } else {
                ForEach(sessions) { session in
                    SessionRow(session: session)
                }
            }
        }
        .padding(14)
        .frame(width: 280)
        .background(
            RoundedRectangle(cornerRadius: 14)
                .fill(.thinMaterial)
                .shadow(radius: 12, y: 6)
        )
    }
}

private struct SessionRow: View {
    let session: BuddySession

    var body: some View {
        HStack(spacing: 10) {
            Circle()
                .fill(badgeColor)
                .frame(width: 8, height: 8)
            VStack(alignment: .leading, spacing: 2) {
                Text(session.key.agent.rawValue)
                    .font(.caption.monospaced())
                Text(session.state.rawValue)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            if let lastEventName = session.lastEventName {
                Text(lastEventName)
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
                    .lineLimit(1)
            }
        }
    }

    private var badgeColor: Color {
        switch session.state {
        case .error: return .red
        case .notification, .attention: return .orange
        case .working, .juggling, .carrying, .sweeping: return .blue
        case .thinking: return .purple
        case .idle: return .green
        case .sleeping, .yawning, .dozing, .collapsing, .waking: return .gray
        }
    }
}
