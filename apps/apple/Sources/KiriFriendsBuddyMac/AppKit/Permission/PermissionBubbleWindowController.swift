// PermissionBubbleWindowController.swift
// Floating NSWindow for a single pending permission request. Positioned
// in the bottom-right corner of the main screen and stacked upward as
// additional requests arrive. Ports
// `.workspace/reference/clawd-on-desk/src/permission.js` window logic.

import AppKit
import KiriFriendsMacBuddyKit
import SwiftUI

@MainActor
public final class PermissionBubbleWindowController: NSWindowController {
    private static let bubbleWidth: CGFloat = 380
    private static let bubbleHeight: CGFloat = 168
    private static let stackInsetX: CGFloat = 16
    private static let stackInsetY: CGFloat = 24
    private static let stackSpacing: CGFloat = 12

    public let request: PermissionBubbleRequest
    private let onDecide: @MainActor @Sendable (PermissionResponse) -> Void

    public init(
        request: PermissionBubbleRequest,
        onDecide: @escaping @MainActor @Sendable (PermissionResponse) -> Void
    ) {
        self.request = request
        self.onDecide = onDecide

        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: Self.bubbleWidth, height: Self.bubbleHeight),
            styleMask: [.borderless],
            backing: .buffered,
            defer: false
        )
        window.isOpaque = false
        window.backgroundColor = .clear
        window.hasShadow = false
        window.level = .modalPanel
        window.collectionBehavior = [.canJoinAllSpaces, .stationary, .fullScreenAuxiliary]
        window.isMovable = false
        window.isMovableByWindowBackground = false

        let hosting = NSHostingController(rootView: PermissionBubbleView(
            request: request,
            onDecide: onDecide
        ))
        window.contentViewController = hosting

        super.init(window: window)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) is not supported")
    }

    public func place(atStackIndex index: Int) {
        guard let window = window, let screen = NSScreen.main else { return }
        let frame = screen.visibleFrame
        let totalOffset = CGFloat(index) * (Self.bubbleHeight + Self.stackSpacing)
        let origin = NSPoint(
            x: frame.maxX - Self.bubbleWidth - Self.stackInsetX,
            y: frame.minY + Self.stackInsetY + totalOffset
        )
        window.setFrameOrigin(origin)
    }

    public func reveal() {
        showWindow(nil)
        window?.orderFrontRegardless()
    }

    public func dismiss() {
        close()
    }
}
