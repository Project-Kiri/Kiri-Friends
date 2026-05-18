// PermissionBubbleView.swift
// SwiftUI content for an individual permission bubble. Renders the
// agent's pending tool request and emits user decisions back to the
// `PermissionBubbleService` actor that owns the request lifecycle.

import KiriFriendsMacBuddyKit
import SwiftUI

struct PermissionBubbleView: View {
    let request: PermissionBubbleRequest
    let onDecide: @MainActor (PermissionResponse) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            header

            Text(request.payload.toolName)
                .font(.callout.monospaced())
                .foregroundStyle(.primary)
            if let description = request.payload.toolInputDescription, !description.isEmpty {
                Text(description)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .lineLimit(3)
            }
            actionButtons

            shortcutHint
        }
        .padding(16)
        .frame(width: 360)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(.thickMaterial)
                .shadow(radius: 18, y: 8)
        )
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Permission request from \(request.agent.rawValue): \(request.payload.toolName)")
    }

    private var header: some View {
        HStack(spacing: 8) {
            Image(systemName: "hand.tap.fill")
                .symbolRenderingMode(.hierarchical)
                .foregroundStyle(.orange)
            Text("Approval needed")
                .font(.headline)
            Spacer()
            Text(request.agent.rawValue)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }

    private var actionButtons: some View {
        HStack(spacing: 8) {
            Button(role: .destructive) {
                onDecide(PermissionResponse(behavior: .deny))
            } label: {
                Label("Deny", systemImage: "xmark.circle")
            }
            .buttonStyle(.bordered)
            .keyboardShortcut("n", modifiers: [.control, .shift])
            .accessibilityHint("Deny this tool request. Shortcut: Control-Shift-N.")

            Spacer()

            Button {
                onDecide(PermissionResponse(behavior: .ask, message: "Always"))
            } label: {
                Label("Always", systemImage: "checkmark.shield")
            }
            .buttonStyle(.bordered)
            .accessibilityHint("Allow this tool and remember the choice.")

            Button {
                onDecide(PermissionResponse(behavior: .allow))
            } label: {
                Label("Allow", systemImage: "checkmark.circle")
            }
            .buttonStyle(.borderedProminent)
            .keyboardShortcut("y", modifiers: [.control, .shift])
            .accessibilityHint("Allow this tool request. Shortcut: Control-Shift-Y.")
        }
    }

    private var shortcutHint: some View {
        HStack(spacing: 4) {
            Spacer()
            Image(systemName: "keyboard")
                .font(.caption2)
                .foregroundStyle(.secondary)
            Text("Control-Shift-Y to Allow · Control-Shift-N to Deny")
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
    }
}
