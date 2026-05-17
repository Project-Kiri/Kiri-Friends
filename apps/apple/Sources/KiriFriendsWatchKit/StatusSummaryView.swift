import KiriFriendsCore
import SwiftUI

public struct StatusSummaryView: View {
    private let snapshot: StateSnapshot

    public init(snapshot: StateSnapshot) {
        self.snapshot = snapshot
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(snapshot.activeTool.rawValue)
                    .font(.headline)
                Spacer()
                Circle()
                    .fill(statusColor)
                    .frame(width: 8, height: 8)
                    .accessibilityHidden(true)
            }

            if let session = snapshot.session {
                Text(session.title)
                    .font(.body)
                    .lineLimit(1)
                Text(session.summary)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
            } else {
                Text("Ready")
                    .font(.body)
            }
        }
        .accessibilityElement(children: .combine)
    }

    private var statusColor: Color {
        switch snapshot.session?.state {
        case .waitingForApproval:
            return .orange
        case .running:
            return .green
        case .failed:
            return .red
        case .completed:
            return .blue
        case .idle, .waitingForInput, .unknown, .none:
            return .secondary
        }
    }
}
