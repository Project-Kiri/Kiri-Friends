// BuddyClickReactionTracker.swift
// Counts consecutive clicks within a short window so the desktop buddy
// can react to double-click ("poke") and 4-click ("flail") gestures.
// Ports the click-reaction state machine in
// `.workspace/reference/clawd-on-desk/src/hit-geometry.js`.

import Foundation

public struct BuddyClickReaction: Sendable, Hashable {
    public enum Kind: String, Sendable, Hashable {
        case single
        case poke
        case flail
    }

    public var kind: Kind
    public var consecutiveCount: Int
    public var lastClickAt: Date

    public init(kind: Kind, consecutiveCount: Int, lastClickAt: Date) {
        self.kind = kind
        self.consecutiveCount = consecutiveCount
        self.lastClickAt = lastClickAt
    }
}

public struct BuddyClickReactionTracker: Sendable {
    public var streakWindow: TimeInterval = 0.45
    public var pokeAt: Int = 2
    public var flailAt: Int = 4

    private var streak: Int = 0
    private var lastClickAt: Date?

    public init() {}

    public mutating func registerClick(at now: Date = Date()) -> BuddyClickReaction {
        if let lastClickAt, now.timeIntervalSince(lastClickAt) <= streakWindow {
            streak += 1
        } else {
            streak = 1
        }
        self.lastClickAt = now

        let kind: BuddyClickReaction.Kind = {
            if streak >= flailAt { return .flail }
            if streak >= pokeAt { return .poke }
            return .single
        }()
        return BuddyClickReaction(kind: kind, consecutiveCount: streak, lastClickAt: now)
    }

    public mutating func reset() {
        streak = 0
        lastClickAt = nil
    }
}
