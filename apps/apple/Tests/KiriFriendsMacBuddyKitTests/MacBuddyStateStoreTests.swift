// MacBuddyStateStoreTests.swift
// Covers the state machine behaviour ported from
// .workspace/reference/clawd-on-desk/src/state.js. Focuses on the
// invariants we care about for cross-device parity: priority resolution,
// multi-session merging, one-shot auto-return, permission lock, and
// session eviction.

import Foundation
import KiriFriendsCore
import KiriFriendsMacBuddyKit
import Testing

@Suite("MacBuddyStateStore")
struct MacBuddyStateStoreTests {
    @Test("Empty store reports sleeping")
    func emptyStoreReportsSleeping() async {
        let store = MacBuddyStateStore()
        let snapshot = await store.currentSnapshot()
        #expect(snapshot.displayState == .sleeping)
        #expect(snapshot.sessions.isEmpty)
    }

    @Test("Single session drives the display state")
    func singleSessionDisplay() async {
        let store = MacBuddyStateStore()
        await store.apply(event: MacBuddyStateEvent(
            agent: .claudeCode,
            sessionId: "a",
            event: "UserPromptSubmit",
            resolvedState: .thinking
        ))
        let snapshot = await store.currentSnapshot()
        #expect(snapshot.displayState == .thinking)
        #expect(snapshot.sessions.count == 1)
    }

    @Test("Higher priority session wins")
    func priorityResolution() async {
        let store = MacBuddyStateStore()
        await store.apply(event: MacBuddyStateEvent(
            agent: .claudeCode,
            sessionId: "a",
            event: "UserPromptSubmit",
            resolvedState: .thinking
        ))
        await store.apply(event: MacBuddyStateEvent(
            agent: .codex,
            sessionId: "b",
            event: "PostToolUseFailure",
            resolvedState: .error
        ))
        let snapshot = await store.currentSnapshot()
        #expect(snapshot.displayState == .error)
    }

    @Test("Permission lock forces notification")
    func permissionLockOverridesDisplayState() async {
        let store = MacBuddyStateStore()
        await store.apply(event: MacBuddyStateEvent(
            agent: .claudeCode,
            sessionId: "a",
            event: "PreToolUse",
            resolvedState: .working
        ))
        await store.setPermissionLocked(true)
        let snapshot = await store.currentSnapshot()
        #expect(snapshot.displayState == .notification)
        #expect(snapshot.permissionLocked == true)
    }

    @Test("Sleeping event removes the session")
    func sleepingClearsSession() async {
        let store = MacBuddyStateStore()
        let agent = AgentIdentifier.claudeCode
        let sessionId = "a"
        await store.apply(event: MacBuddyStateEvent(
            agent: agent,
            sessionId: sessionId,
            event: "PreToolUse",
            resolvedState: .working
        ))
        await store.apply(event: MacBuddyStateEvent(
            agent: agent,
            sessionId: sessionId,
            event: "SessionEnd",
            resolvedState: .sleeping
        ))
        let snapshot = await store.currentSnapshot()
        #expect(snapshot.sessions.isEmpty)
        #expect(snapshot.displayState == .sleeping)
    }

    @Test("One-shot auto-return falls back to idle")
    func oneShotAutoReturn() async throws {
        let store = MacBuddyStateStore(timings: MacBuddyStateStore.Timings(
            attention: .milliseconds(40),
            error: .milliseconds(40),
            sweeping: .milliseconds(40),
            notification: .milliseconds(40),
            carrying: .milliseconds(40)
        ))
        await store.apply(event: MacBuddyStateEvent(
            agent: .claudeCode,
            sessionId: "a",
            event: "Stop",
            resolvedState: .attention
        ))
        #expect(await store.currentSnapshot().displayState == .attention)
        try await Task.sleep(for: .milliseconds(300))
        #expect(await store.currentSnapshot().displayState == .idle)
    }

    @Test("Reset drops all sessions and clears permission lock")
    func resetDrops() async {
        let store = MacBuddyStateStore()
        await store.apply(event: MacBuddyStateEvent(
            agent: .claudeCode,
            sessionId: "a",
            event: "PreToolUse",
            resolvedState: .working
        ))
        await store.setPermissionLocked(true)
        await store.reset()
        let snapshot = await store.currentSnapshot()
        #expect(snapshot.sessions.isEmpty)
        #expect(snapshot.displayState == .sleeping)
        #expect(snapshot.permissionLocked == false)
    }

    @Test("Subscription receives a snapshot on apply")
    func subscriptionReceivesSnapshots() async throws {
        let store = MacBuddyStateStore()
        let stream = await store.subscribe()
        var iterator = stream.makeAsyncIterator()

        // Initial yielded snapshot is the sleeping baseline.
        let initial = await iterator.next()
        #expect(initial?.displayState == .sleeping)

        await store.apply(event: MacBuddyStateEvent(
            agent: .claudeCode,
            sessionId: "a",
            event: "UserPromptSubmit",
            resolvedState: .thinking
        ))
        let snapshot = await iterator.next()
        #expect(snapshot?.displayState == .thinking)
    }
}
