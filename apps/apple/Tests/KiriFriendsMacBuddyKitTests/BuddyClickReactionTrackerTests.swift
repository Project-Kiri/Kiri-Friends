// BuddyClickReactionTrackerTests.swift
// Pins the consecutive-click counting that drives the buddy's poke /
// flail reactions.

import Foundation
import KiriFriendsMacBuddyKit
import Testing

@Suite("BuddyClickReactionTracker")
struct BuddyClickReactionTrackerTests {
    @Test("Single click reports as single")
    func singleClick() {
        var tracker = BuddyClickReactionTracker()
        let reaction = tracker.registerClick(at: Date(timeIntervalSince1970: 0))
        #expect(reaction.kind == .single)
        #expect(reaction.consecutiveCount == 1)
    }

    @Test("Two clicks inside the streak window upgrade to poke")
    func twoClicksPoke() {
        var tracker = BuddyClickReactionTracker()
        let first = Date(timeIntervalSince1970: 0)
        _ = tracker.registerClick(at: first)
        let second = tracker.registerClick(at: first.addingTimeInterval(0.3))
        #expect(second.kind == .poke)
        #expect(second.consecutiveCount == 2)
    }

    @Test("Four clicks in a row reach flail")
    func fourClicksFlail() {
        var tracker = BuddyClickReactionTracker()
        var ts = Date(timeIntervalSince1970: 0)
        for _ in 0..<3 {
            _ = tracker.registerClick(at: ts)
            ts.addTimeInterval(0.2)
        }
        let fourth = tracker.registerClick(at: ts)
        #expect(fourth.kind == .flail)
        #expect(fourth.consecutiveCount == 4)
    }

    @Test("Clicks outside the window reset the streak")
    func windowExpiresStreak() {
        var tracker = BuddyClickReactionTracker()
        let start = Date(timeIntervalSince1970: 0)
        _ = tracker.registerClick(at: start)
        let resumed = tracker.registerClick(at: start.addingTimeInterval(2))
        #expect(resumed.kind == .single)
        #expect(resumed.consecutiveCount == 1)
    }
}
