import Foundation
import Testing
@testable import KiriFriendsBridge
@testable import KiriFriendsCore

@Suite("BridgeStateStore folding")
struct BridgeStateStoreFoldingTests {
    @MainActor
    @Test("Session.started seeds an idle session keyed by agent")
    func sessionStartedSeedsIdle() {
        let store = BridgeStateStore(latestSnapshot: emptySnapshot())
        store.apply(event: makeEvent(event: "session.started", tool: "claude-code", sessionId: "s-1"))

        let snapshot = store.latestSnapshot
        #expect(snapshot.sessions.count == 1)
        #expect(snapshot.session?.tool == .claudeCode)
        #expect(snapshot.session?.state == .idle)
        #expect(snapshot.activeTool == .claudeCode)
    }

    @MainActor
    @Test("Two agents fold into two distinct sessions")
    func twoAgentsFoldDistinctly() {
        let store = BridgeStateStore(latestSnapshot: emptySnapshot())
        store.apply(events: [
            makeEvent(event: "session.started", tool: "codex", sessionId: "codex-1"),
            makeEvent(event: "session.started", tool: "claude-code", sessionId: "claude-1"),
            makeEvent(event: "tool.started", tool: "claude-code", sessionId: "claude-1"),
        ])

        let snapshot = store.latestSnapshot
        #expect(snapshot.sessions.count == 2)
        #expect(snapshot.sessions.contains(where: { $0.tool == .codex && $0.state == .idle }))
        #expect(snapshot.sessions.contains(where: { $0.tool == .claudeCode && $0.state == .running }))
    }

    @MainActor
    @Test("Approval requested wins priority over running")
    func approvalWinsPriority() {
        let store = BridgeStateStore(latestSnapshot: emptySnapshot())
        store.apply(events: [
            makeEvent(event: "tool.started", tool: "claude-code", sessionId: "claude-1"),
            makeEvent(event: "approval.requested", tool: "codex", sessionId: "codex-1"),
        ])

        let snapshot = store.latestSnapshot
        #expect(snapshot.session?.state == .waitingForApproval)
        #expect(snapshot.session?.tool == .codex)
        #expect(snapshot.approval != nil)
        #expect(snapshot.approval?.sessionId == "codex-1")
    }

    @MainActor
    @Test("Session.failed transitions a tracked session into failed")
    func sessionFailed() {
        let store = BridgeStateStore(latestSnapshot: emptySnapshot())
        store.apply(events: [
            makeEvent(event: "session.started", tool: "codex", sessionId: "codex-1"),
            makeEvent(event: "session.failed", tool: "codex", sessionId: "codex-1"),
        ])
        #expect(store.latestSnapshot.session?.state == .failed)
    }

    @MainActor
    @Test("output.preview does not change the snapshot")
    func outputPreviewIsNoOp() {
        let store = BridgeStateStore(latestSnapshot: emptySnapshot())
        store.apply(event: makeEvent(event: "session.started", tool: "codex", sessionId: "codex-1"))
        let before = store.latestSnapshot
        store.apply(event: makeEvent(event: "output.preview", tool: "codex", sessionId: "codex-1"))
        let after = store.latestSnapshot
        #expect(before.sessions == after.sessions)
    }

    @MainActor
    @Test("Last event id is preserved for cursor resume")
    func lastEventIdTracked() {
        let store = BridgeStateStore(latestSnapshot: emptySnapshot())
        let event = makeEvent(event: "session.started", tool: "codex", sessionId: "codex-1", eventId: "evt-42")
        store.apply(event: event)
        #expect(store.lastEventId == "evt-42")
    }

    @MainActor
    @Test("Top-level relay tool drives session identity")
    func topLevelRelayToolDrivesSessionIdentity() {
        let store = BridgeStateStore(latestSnapshot: emptySnapshot())
        store.apply(event: RelayEventEnvelope(
            eventId: "evt-top-level-tool",
            version: 1,
            userId: "user-1",
            sourceDeviceId: "device-mac",
            tool: "codex",
            event: "approval.requested",
            sessionId: "codex-1",
            cwd: "/tmp/project",
            createdAt: Date(),
            payload: ["summary": .string("Run tests")]
        ))

        #expect(store.latestSnapshot.session?.tool == .codex)
        #expect(store.latestSnapshot.session?.state == .waitingForApproval)
        #expect(store.latestSnapshot.session?.summary == "Run tests")
    }

    private func emptySnapshot() -> StateSnapshot {
        StateSnapshot(
            updatedAt: Date(timeIntervalSince1970: 0),
            activeTool: .unknown,
            connectionState: .relayConnected,
            session: nil
        )
    }

    private func makeEvent(
        event: String,
        tool: String,
        sessionId: String,
        eventId: String? = nil
    ) -> RelayEventEnvelope {
        RelayEventEnvelope(
            eventId: eventId ?? UUID().uuidString,
            userId: "user-1",
            sourceDeviceId: "device-mac",
            event: event,
            sessionId: sessionId,
            createdAt: Date(),
            payload: ["tool": .string(tool)]
        )
    }
}

@Suite("BridgeRuntime end-to-end")
struct BridgeRuntimeTests {
    @MainActor
    @Test("Approval event flows through to the bridge store")
    func approvalEventFolds() async {
        let downlink = InMemoryRelayDownlinkClient()
        let runtime = BridgeRuntime(
            store: BridgeStateStore(latestSnapshot: emptySnapshot()),
            client: downlink,
            watchController: nil,
            appGroupStore: nil,
            userId: "user-1",
            macDeviceId: "mac-1"
        )

        await runtime.start()
        await downlink.emit(RelayEventEnvelope(
            eventId: "evt-1",
            userId: "user-1",
            sourceDeviceId: "mac-1",
            event: "approval.requested",
            sessionId: "codex-1",
            createdAt: Date(),
            payload: ["tool": .string("codex"), "summary": .string("Run tests")]
        ))

        try? await Task.sleep(for: .milliseconds(80))
        let snapshot = runtime.store.latestSnapshot
        #expect(snapshot.session?.state == .waitingForApproval)
        #expect(snapshot.session?.tool == .codex)
        #expect(snapshot.session?.summary == "Run tests")
        runtime.stop()
    }

    @MainActor
    @Test("Watch action handler is invoked for incoming actions")
    func watchActionHandlerFires() async {
        let downlink = InMemoryRelayDownlinkClient()
        let runtime = BridgeRuntime(
            client: downlink,
            watchController: nil,
            appGroupStore: nil,
            userId: "user-1",
            macDeviceId: "mac-1"
        )
        var observed: WatchAction?
        runtime.setWatchActionHandler { observed = $0 }
        // Simulate a direct call by accessing the runtime's handler path
        // (no real WC controller is attached in tests).
        let action = WatchAction(
            action: .approvalAllow,
            sessionId: "codex-1",
            approvalId: "appr-1",
            createdAt: Date()
        )
        runtime.handleForTesting(action: action)
        try? await Task.sleep(for: .milliseconds(40))
        #expect(observed?.action == .approvalAllow)
        let sentRequests = await downlink.sentRequests
        #expect(sentRequests.count == 1)
        #expect(sentRequests.first?.kind == "approval.allow")
    }

    @MainActor
    @Test("Health summary is gated by sharing setting")
    func healthSummarySharingIsGated() {
        let runtime = BridgeRuntime(
            store: BridgeStateStore(latestSnapshot: emptySnapshot()),
            client: InMemoryRelayDownlinkClient(),
            watchController: nil,
            appGroupStore: nil,
            userId: "user-1",
            macDeviceId: "mac-1"
        )

        runtime.handleHealthSummaryForTesting(.placeholder)
        #expect(runtime.store.latestSnapshot.healthSummary == nil)

        runtime.setSharesHealthContext(true)
        runtime.handleHealthSummaryForTesting(.placeholder)
        #expect(runtime.store.latestSnapshot.healthSummary == .placeholder)

        runtime.setSharesHealthContext(false)
        #expect(runtime.store.latestSnapshot.healthSummary == nil)
    }

    private func emptySnapshot() -> StateSnapshot {
        StateSnapshot(
            updatedAt: Date(timeIntervalSince1970: 0),
            activeTool: .unknown,
            connectionState: .relayConnected,
            session: nil
        )
    }
}
