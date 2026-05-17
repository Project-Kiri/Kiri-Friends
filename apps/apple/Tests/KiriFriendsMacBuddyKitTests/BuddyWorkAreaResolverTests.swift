// BuddyWorkAreaResolverTests.swift
// Locks in the cross-monitor clamp logic so dragging the buddy never
// loses it offscreen after a display changes.

import Foundation
import KiriFriendsMacBuddyKit
import Testing

@Suite("BuddyWorkAreaResolver")
struct BuddyWorkAreaResolverTests {
    private let primary = BuddyWorkArea(minX: 0, minY: 0, maxX: 1920, maxY: 1080, displayIdentifier: 1)
    private let secondary = BuddyWorkArea(minX: 1920, minY: 0, maxX: 3840, maxY: 1440, displayIdentifier: 2)

    @Test("Origin inside primary stays on primary")
    func originInsidePrimary() {
        let result = BuddyWorkAreaResolver.nearest(origin: CGPoint(x: 100, y: 100), in: [primary, secondary])
        #expect(result?.displayIdentifier == 1)
    }

    @Test("Origin inside secondary stays on secondary")
    func originInsideSecondary() {
        let result = BuddyWorkAreaResolver.nearest(origin: CGPoint(x: 2400, y: 600), in: [primary, secondary])
        #expect(result?.displayIdentifier == 2)
    }

    @Test("Off-screen origin snaps to the nearest area")
    func offscreenSnaps() {
        let result = BuddyWorkAreaResolver.nearest(origin: CGPoint(x: -500, y: 600), in: [primary, secondary])
        #expect(result?.displayIdentifier == 1)
    }

    @Test("Clamp keeps the window inside the work area")
    func clampInside() {
        let clamped = primary.clamped(origin: CGPoint(x: 2000, y: 2000), size: CGSize(width: 200, height: 200))
        #expect(clamped.x == 1720)
        #expect(clamped.y == 880)
    }
}
