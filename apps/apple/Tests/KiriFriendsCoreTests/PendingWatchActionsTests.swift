import Foundation
import KiriFriendsCore
import KiriFriendsWatchKit
import Testing

@Test func pendingActionOptionsReflectHookDrivenStates() {
    let approval = snapshot(state: .waitingForApproval)
    #expect(PendingWatchActionOption.options(for: approval).map(\.action) == [.approvalAllow, .approvalDeny])

    let input = snapshot(state: .waitingForInput)
    #expect(PendingWatchActionOption.options(for: input).map(\.action) == [.promptSendQuick])

    let running = snapshot(state: .running)
    #expect(PendingWatchActionOption.options(for: running).isEmpty)
}

@Test func pendingActionOptionsUseSelectedCommandSession() {
    let primary = CLISessionSummary(
        id: "primary",
        state: .running,
        title: "Primary",
        summary: "Running",
        sensitivity: .none,
        tool: .codex
    )
    let selected = CLISessionSummary(
        id: "selected",
        state: .waitingForApproval,
        title: "Selected",
        summary: "Needs approval",
        sensitivity: .preview,
        tool: .claudeCode
    )
    let state = StateSnapshot(
        updatedAt: Date(timeIntervalSince1970: 0),
        activeTool: .codex,
        connectionState: .relayConnected,
        session: primary,
        sessions: [primary, selected]
    )

    #expect(PendingWatchActionOption.options(for: state).isEmpty)
    #expect(PendingWatchActionOption.options(for: state, targetSession: selected).map(\.action) == [.approvalAllow, .approvalDeny])
}

@Test func wristTurnClassifierRequiresThresholdAndNeutralReset() {
    var classifier = WristTurnClassifier(
        triggerThreshold: 0.35,
        neutralThreshold: 0.12,
        cooldown: 0.5
    )
    let start = Date(timeIntervalSince1970: 10)

    #expect(classifier.update(rollDelta: 0.2, at: start) == nil)
    #expect(classifier.update(rollDelta: 0.4, at: start.addingTimeInterval(0.1)) == .next)
    #expect(classifier.update(rollDelta: 0.5, at: start.addingTimeInterval(1.0)) == nil)
    #expect(classifier.update(rollDelta: 0.0, at: start.addingTimeInterval(1.1)) == nil)
    #expect(classifier.update(rollDelta: -0.4, at: start.addingTimeInterval(1.2)) == .previous)
}

@Test func wristTurnClassifierDebouncesCooldown() {
    var classifier = WristTurnClassifier(
        triggerThreshold: 0.35,
        neutralThreshold: 0.12,
        cooldown: 0.5
    )
    let start = Date(timeIntervalSince1970: 20)

    #expect(classifier.update(rollDelta: 0.4, at: start) == .next)
    #expect(classifier.update(rollDelta: 0.0, at: start.addingTimeInterval(0.1)) == nil)
    #expect(classifier.update(rollDelta: -0.4, at: start.addingTimeInterval(0.2)) == nil)
    #expect(classifier.update(rollDelta: -0.4, at: start.addingTimeInterval(0.6)) == .previous)
}

private func snapshot(state: SessionState) -> StateSnapshot {
    StateSnapshot(
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
}
