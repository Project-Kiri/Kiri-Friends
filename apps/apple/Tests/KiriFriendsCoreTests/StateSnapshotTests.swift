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
