// BuddyWorkAreaResolver.swift
// Clamps the buddy window origin to the visible work area of the
// nearest display. Mirrors
// `.workspace/reference/clawd-on-desk/src/work-area.js` so cross-monitor
// drags land in a usable region even after a display is unplugged.

import Foundation

public struct BuddyWorkArea: Sendable, Hashable {
    public var minX: Double
    public var minY: Double
    public var maxX: Double
    public var maxY: Double
    public var displayIdentifier: UInt32?

    public init(minX: Double, minY: Double, maxX: Double, maxY: Double, displayIdentifier: UInt32? = nil) {
        self.minX = minX
        self.minY = minY
        self.maxX = maxX
        self.maxY = maxY
        self.displayIdentifier = displayIdentifier
    }

    public func clamped(origin: CGPoint, size: CGSize) -> CGPoint {
        let clampedX = min(max(origin.x, minX), maxX - size.width)
        let clampedY = min(max(origin.y, minY), maxY - size.height)
        return CGPoint(x: clampedX, y: clampedY)
    }
}

public enum BuddyWorkAreaResolver {
    /// Returns the work area that should host a window placed at
    /// `origin`. When the desired origin falls on a known display, that
    /// display wins; otherwise the closest display by Manhattan distance
    /// wins. Mirrors upstream `findNearestWorkArea`.
    public static func nearest(
        origin: CGPoint,
        in areas: [BuddyWorkArea]
    ) -> BuddyWorkArea? {
        guard !areas.isEmpty else { return nil }
        if let containing = areas.first(where: { contains(origin: origin, in: $0) }) {
            return containing
        }
        return areas.min(by: { lhs, rhs in
            distance(from: origin, to: lhs) < distance(from: origin, to: rhs)
        })
    }

    private static func contains(origin: CGPoint, in area: BuddyWorkArea) -> Bool {
        origin.x >= area.minX && origin.x <= area.maxX &&
            origin.y >= area.minY && origin.y <= area.maxY
    }

    private static func distance(from origin: CGPoint, to area: BuddyWorkArea) -> Double {
        let dx = max(area.minX - origin.x, 0, origin.x - area.maxX)
        let dy = max(area.minY - origin.y, 0, origin.y - area.maxY)
        return dx + dy
    }
}
