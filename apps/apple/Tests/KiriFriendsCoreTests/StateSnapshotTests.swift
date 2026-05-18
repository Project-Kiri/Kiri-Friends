import Foundation
import Testing
@testable import KiriFriendsCore

@Test func stateSnapshotRoundTripsThroughJSON() throws {
    let snapshot = StateSnapshot.placeholder
    let data = try KiriJSON.encoder.encode(snapshot)
    let decoded = try KiriJSON.decoder.decode(StateSnapshot.self, from: data)

    #expect(decoded == snapshot)
    #expect(decoded.kind == "state.snapshot")
    #expect(decoded.session?.state == .waitingForApproval)
}

@Test func watchActionUsesDocumentedKind() {
    let action = WatchAction(
        action: .approvalAllow,
        sessionId: "session-uuid",
        approvalId: "approval-uuid",
        createdAt: Date(timeIntervalSince1970: 1_779_020_400)
    )

    #expect(action.schemaVersion == 1)
    #expect(action.kind == "watch.action")
    #expect(action.action == .approvalAllow)
}

@Test func decodesSharedStateSnapshotFixture() throws {
    let data = try fixtureData("state-snapshot.codex.approval.json")
    let snapshot = try KiriJSON.decoder.decode(StateSnapshot.self, from: data)

    #expect(snapshot.activeTool == .codex)
    #expect(snapshot.connectionState == .relayConnected)
    #expect(snapshot.session?.state == .waitingForApproval)
}

@Test func decodesSharedWatchActionFixture() throws {
    let data = try fixtureData("watch-action.approval-allow.json")
    let action = try KiriJSON.decoder.decode(WatchAction.self, from: data)

    #expect(action.action == .approvalAllow)
    #expect(action.sessionId == "session-uuid")
    #expect(action.approvalId == "approval-uuid")
}

@Test func derivesBuddyPresentationForApproval() {
    let presentation = BuddyPresentationReducer.presentation(for: .placeholder)

    #expect(presentation.state == .attention)
    #expect(presentation.primaryAction == .approvalAllow)
    #expect(presentation.speech.text == "")
    #expect(presentation.speech.sensitivity == .none)
}

@Test func buddyPresentationDoesNotTurnCLIContextIntoPetSpeech() {
    let snapshot = StateSnapshot(
        updatedAt: Date(timeIntervalSince1970: 0),
        activeTool: .codex,
        connectionState: .relayConnected,
        session: CLISessionSummary(
            id: "running-session",
            state: .running,
            title: "Codex",
            summary: "make test-server",
            sensitivity: .none,
            tool: .codex
        )
    )

    let presentation = BuddyPresentationReducer.presentation(for: snapshot)
    #expect(presentation.state == .running)
    #expect(presentation.speech.text == "")
}

@Test func primaryActionOnlyExistsForHookDrivenStates() {
    let states: [(SessionState, WatchActionKind?)] = [
        (.waitingForApproval, .approvalAllow),
        (.waitingForInput, .promptSendQuick),
        (.running, nil),
        (.idle, nil),
        (.completed, nil),
        (.failed, nil),
        (.unknown, nil),
    ]

    for (state, expected) in states {
        let snapshot = StateSnapshot(
            updatedAt: Date(timeIntervalSince1970: 0),
            activeTool: .codex,
            connectionState: .relayConnected,
            session: CLISessionSummary(
                id: "s-\(state.rawValue)",
                state: state,
                title: "Codex",
                summary: "",
                sensitivity: .none,
                tool: .codex
            )
        )
        let presentation = BuddyPresentationReducer.presentation(for: snapshot)
        #expect(presentation.primaryAction == expected, "state \(state.rawValue) should map to \(String(describing: expected))")
    }
}

@Test func primaryActionIsNilWhenNoSession() {
    let snapshot = StateSnapshot(
        updatedAt: Date(timeIntervalSince1970: 0),
        activeTool: .unknown,
        connectionState: .relayConnected,
        session: nil
    )
    #expect(BuddyPresentationReducer.presentation(for: snapshot).primaryAction == nil)
}

@Test func derivesComplicationSnapshotWithoutPrivateText() {
    let complication = BuddyPresentationReducer.complicationSnapshot(for: .placeholder)

    #expect(complication.shortStatus == "Approval")
    #expect(complication.detail == "Action needed")
    #expect(complication.sensitivity == .none)
}

@Test func complicationAppendsPlusNWhenAdditionalSessions() throws {
    let data = try fixtureData("state-snapshot.multi-session.json")
    let snapshot = try KiriJSON.decoder.decode(StateSnapshot.self, from: data)
    let complication = BuddyPresentationReducer.complicationSnapshot(for: snapshot)
    #expect(complication.detail?.contains("+2") == true)
}

@Test func agentBadgeProducesNonEmptySymbolForEveryAgent() {
    for tool in CLITool.allCases {
        let badge = BuddyPresentationReducer.agentBadge(for: tool)
        #expect(!badge.symbolName.isEmpty)
        #expect(!badge.label.isEmpty)
    }
}

@Test func decodesSharedBuddyAssetManifestFixture() throws {
    let data = try fixtureData("buddy-asset.manifest.json")
    let manifest = try KiriJSON.decoder.decode(BuddyAssetManifest.self, from: data)

    #expect(manifest.identifier == "com.kirifriends.bufo")
    #expect(manifest.missingRequiredStates.isEmpty)
}

@Test func decodesSharedHealthSignalFixture() throws {
    let data = try fixtureData("health-signal.summary.json")
    let summary = try KiriJSON.decoder.decode(HealthSignalSummary.self, from: data)

    #expect(summary.kind == "health.signal.summary")
    #expect(summary.activityState == .focused)
}

@Test func decodesSharedComplicationFixture() throws {
    let data = try fixtureData("complication-snapshot.approval.json")
    let snapshot = try KiriJSON.decoder.decode(ComplicationSnapshot.self, from: data)

    #expect(snapshot.shortStatus == "Approval")
    #expect(snapshot.symbolName == "hand.tap")
}

@Test func cliToolCoversAllTwelveAgents() {
    let expected: Set<CLITool> = [
        .claudeCode, .codex, .copilotCli, .geminiCli, .cursorAgent,
        .codebuddy, .kiroCli, .kimiCli, .opencode, .pi, .openclaw, .hermes,
        .unknown,
    ]
    #expect(Set(CLITool.allCases) == expected)
}

@Test func cliToolDecodesUnknownAsPlaceholder() throws {
    let json = Data(#""new-agent-that-does-not-exist""#.utf8)
    let value = try KiriJSON.decoder.decode(CLITool.self, from: json)
    #expect(value == .unknown)
}

@Test func everyAgentRawValueRoundTrips() throws {
    for tool in CLITool.allCases where tool != .unknown {
        let summary = CLISessionSummary(
            id: "s-\(tool.rawValue)",
            state: .running,
            title: tool.rawValue,
            summary: "Active session",
            sensitivity: .none,
            tool: tool
        )
        let data = try KiriJSON.encoder.encode(summary)
        let decoded = try KiriJSON.decoder.decode(CLISessionSummary.self, from: data)
        #expect(decoded == summary)
    }
}

@Test func decodesMultiSessionFixture() throws {
    let data = try fixtureData("state-snapshot.multi-session.json")
    let snapshot = try KiriJSON.decoder.decode(StateSnapshot.self, from: data)

    #expect(snapshot.sessions.count == 3)
    #expect(snapshot.session?.tool == .codex)
    #expect(snapshot.sessions.map(\.tool) == [.codex, .claudeCode, .copilotCli])
    #expect(snapshot.additionalSessionCount == 2)
}

@Test func legacySingleSessionFixtureStillDecodes() throws {
    let data = try fixtureData("state-snapshot.codex.approval.json")
    let snapshot = try KiriJSON.decoder.decode(StateSnapshot.self, from: data)

    #expect(snapshot.sessions.isEmpty)
    #expect(snapshot.session?.tool == nil)
    #expect(snapshot.additionalSessionCount == 0)
}

@Test func buddyPersonaStateProjectsFromMacBuddyRawValues() {
    let sleepStates = ["sleeping", "yawning", "dozing", "collapsing", "waking"]
    for raw in sleepStates {
        #expect(BuddyPersonaState(macBuddyStateRawValue: raw) == .sleep)
    }

    let runningStates = ["thinking", "working", "juggling", "carrying", "sweeping"]
    for raw in runningStates {
        #expect(BuddyPersonaState(macBuddyStateRawValue: raw) == .running)
    }

    #expect(BuddyPersonaState(macBuddyStateRawValue: "idle") == .idle)
    #expect(BuddyPersonaState(macBuddyStateRawValue: "notification") == .attention)
    #expect(BuddyPersonaState(macBuddyStateRawValue: "attention") == .celebrate)
    #expect(BuddyPersonaState(macBuddyStateRawValue: "error") == .failed)
    #expect(BuddyPersonaState(macBuddyStateRawValue: "completely-unknown") == .idle)
}

private func fixtureData(_ name: String) throws -> Data {
    let packageDirectory = URL(fileURLWithPath: #filePath)
        .deletingLastPathComponent()
        .deletingLastPathComponent()
        .deletingLastPathComponent()
    let rootDirectory = packageDirectory
        .deletingLastPathComponent()
        .deletingLastPathComponent()
    return try Data(contentsOf: rootDirectory.appending(path: "fixtures").appending(path: name))
}
