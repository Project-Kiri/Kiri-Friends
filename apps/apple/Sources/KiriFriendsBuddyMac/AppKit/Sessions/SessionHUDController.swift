// SessionHUDController.swift
// Floating NSWindow that hosts the Session HUD. Anchors to the
// bottom-right corner above the permission stack. Ports
// `.workspace/reference/clawd-on-desk/src/session-hud.js` into AppKit.

import AppKit
import KiriFriendsMacBuddyKit
import SwiftUI

@MainActor
public final class SessionHUDController: NSWindowController {
    private static let hudWidth: CGFloat = 300
    private static let hudHeight: CGFloat = 200
    private static let topInset: CGFloat = 16
    private static let rightInset: CGFloat = 16
    private static let baselineOffset: CGFloat = 280

    private let hosting: NSHostingController<HUDHost>

    public init() {
        let host = HUDHost(sessions: [], permissionLocked: false)
        self.hosting = NSHostingController(rootView: host)

        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: Self.hudWidth, height: Self.hudHeight),
            styleMask: [.borderless],
            backing: .buffered,
            defer: false
        )
        window.isOpaque = false
        window.backgroundColor = .clear
        window.hasShadow = false
        window.level = .floating
        window.collectionBehavior = [.canJoinAllSpaces, .stationary, .fullScreenAuxiliary]
        window.isMovable = false
        window.contentViewController = hosting
        super.init(window: window)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) is not supported")
    }

    public func attach() {
        relocate()
        showWindow(nil)
    }

    public func detach() {
        close()
    }

    public func applySnapshot(_ snapshot: MacBuddyDisplaySnapshot) {
        hosting.rootView = HUDHost(
            sessions: snapshot.sessions,
            permissionLocked: snapshot.permissionLocked
        )
    }

    private func relocate() {
        guard let window, let screen = NSScreen.main else { return }
        let frame = screen.visibleFrame
        let origin = NSPoint(
            x: frame.maxX - Self.hudWidth - Self.rightInset,
            y: frame.minY + Self.baselineOffset
        )
        window.setFrameOrigin(origin)
    }
}

private struct HUDHost: View {
    let sessions: [BuddySession]
    let permissionLocked: Bool

    var body: some View {
        SessionHUDView(sessions: sessions, permissionLocked: permissionLocked)
    }
}
