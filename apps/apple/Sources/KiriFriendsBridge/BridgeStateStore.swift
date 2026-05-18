// BridgeStateStore.swift
// Folds incoming relay events into a single `StateSnapshot` that the
// iPhone UI, Watch app, and complication widget all consume. The
// folding rules mirror the Mac Buddy state machine in
// apps/apple/Sources/KiriFriendsMacBuddyKit/State/MacBuddyStateStore.swift
// but project everything onto the narrower `SessionState` vocabulary the
// rest of the workspace already speaks.

import Foundation
import KiriFriendsCore
import Observation

@Observable
@MainActor
public final class BridgeStateStore {
    public private(set) var latestSnapshot: StateSnapshot
    public private(set) var lastEventId: String?

    // Sessions are keyed by (agent rawValue, sessionId) so distinct
    // agents do not collide even when they reuse a "default" sessionId.
    private var sessions: [SessionKey: TrackedSession] = [:]

    public init(latestSnapshot: StateSnapshot = .empty) {
        self.latestSnapshot = latestSnapshot
        self.lastEventId = nil
    }

    /// Replaces the snapshot wholesale. Used to seed the placeholder or
    /// to reset state without replaying events.
    public func replace(with snapshot: StateSnapshot) {
        latestSnapshot = snapshot
    }

    /// Resets the folded session map; the snapshot becomes a connection
    /// banner with no tracked sessions.
    public func clearSessions(now: Date = Date()) {
        sessions.removeAll()
        rebuildSnapshot(updatedAt: now, connectionState: latestSnapshot.connectionState)
    }

    public func updateConnectionState(_ connectionState: ConnectionState, now: Date = Date()) {
        latestSnapshot.connectionState = connectionState
        latestSnapshot.updatedAt = now
    }

    public func updateHealthSummary(_ summary: HealthSignalSummary?, now: Date = Date()) {
        latestSnapshot.healthSummary = summary
        latestSnapshot.updatedAt = now
    }

    /// Folds a single relay event into the snapshot. Returns true when
    /// the event meaningfully changed the snapshot (callers can use this
    /// to throttle WC syncs and complication writes).
    @discardableResult
    public func apply(event: RelayEventEnvelope) -> Bool {
        lastEventId = event.eventId
        guard let mutation = Mutation(envelope: event) else { return false }
        let changed = applyMutation(mutation, now: event.createdAt)
        return changed
    }

    /// Convenience for testing; folds a batch in order.
    public func apply<S: Sequence>(events: S) where S.Element == RelayEventEnvelope {
        for event in events { apply(event: event) }
    }
}

// MARK: - Internal types

private extension BridgeStateStore {
    struct SessionKey: Hashable {
        let agent: CLITool
        let sessionId: String
    }

    struct TrackedSession {
        var state: SessionState
        var title: String
        var summary: String
        var sensitivity: PayloadSensitivity
        var tool: CLITool
        var sessionId: String
        var updatedAt: Date
    }

    enum Mutation {
        case upsert(SessionKey, state: SessionState, title: String?, summary: String?, sensitivity: PayloadSensitivity)
        case approval(SessionKey, title: String?, summary: String?, sensitivity: PayloadSensitivity)
        case complete(SessionKey)
        case fail(SessionKey, summary: String?)
        case clearApprovalForAgent(CLITool, sessionId: String)
        case noOp

        init?(envelope: RelayEventEnvelope) {
            let toolRaw = envelope.tool
                ?? envelope.payload["tool"]?.stringValue
                ?? (envelope.payload["payload"].flatMap { value -> String? in
                    if case let .object(nested) = value { return nested["tool"]?.stringValue }
                    return nil
                })
            let tool = CLITool(rawValue: toolRaw ?? "") ?? .unknown
            let sessionId = envelope.sessionId ?? "default"
            let key = SessionKey(agent: tool, sessionId: sessionId)
            let summary = envelope.payload["summary"]?.stringValue
                ?? envelope.payload["toolName"]?.stringValue
            let title = envelope.payload["title"]?.stringValue
            let sensitivity = parseSensitivity(envelope.sensitivity)

            switch envelope.event {
            case "session.started":
                self = .upsert(key, state: .idle, title: title, summary: summary, sensitivity: sensitivity)
            case "prompt.submitted", "tool.started", "tool.completed", "subagent.completed", "approval.completed":
                self = .upsert(key, state: .running, title: title, summary: summary, sensitivity: sensitivity)
            case "session.compacting":
                self = .upsert(key, state: .running, title: title, summary: summary ?? "Compacting", sensitivity: sensitivity)
            case "approval.requested":
                self = .approval(key, title: title, summary: summary, sensitivity: sensitivity)
            case "session.waiting":
                self = .upsert(key, state: .waitingForInput, title: title, summary: summary, sensitivity: sensitivity)
            case "session.completed":
                self = .complete(key)
            case "session.failed":
                self = .fail(key, summary: summary)
            case "output.preview":
                self = .noOp
            default:
                self = .noOp
            }
        }
    }

    func applyMutation(_ mutation: Mutation, now: Date) -> Bool {
        switch mutation {
        case .upsert(let key, let state, let title, let summary, let sensitivity):
            upsertSession(key, state: state, title: title, summary: summary, sensitivity: sensitivity, now: now)
        case .approval(let key, let title, let summary, let sensitivity):
            upsertSession(key, state: .waitingForApproval, title: title, summary: summary, sensitivity: sensitivity, now: now)
        case .complete(let key):
            upsertSession(key, state: .completed, title: nil, summary: nil, sensitivity: .none, now: now)
        case .fail(let key, let summary):
            upsertSession(key, state: .failed, title: nil, summary: summary, sensitivity: .none, now: now)
        case .clearApprovalForAgent(let tool, let sessionId):
            let key = SessionKey(agent: tool, sessionId: sessionId)
            if var session = sessions[key], session.state == .waitingForApproval {
                session.state = .running
                session.updatedAt = now
                sessions[key] = session
            }
        case .noOp:
            return false
        }
        rebuildSnapshot(updatedAt: now, connectionState: latestSnapshot.connectionState)
        return true
    }

    func upsertSession(
        _ key: SessionKey,
        state: SessionState,
        title: String?,
        summary: String?,
        sensitivity: PayloadSensitivity,
        now: Date
    ) {
        var session = sessions[key] ?? TrackedSession(
            state: state,
            title: title ?? key.agent.rawValue,
            summary: summary ?? "",
            sensitivity: sensitivity,
            tool: key.agent,
            sessionId: key.sessionId,
            updatedAt: now
        )
        session.state = state
        if let title { session.title = title }
        if let summary { session.summary = summary }
        session.sensitivity = sensitivity
        session.updatedAt = now
        sessions[key] = session
    }

    func rebuildSnapshot(updatedAt: Date, connectionState: ConnectionState) {
        let summaries = sessions.values
            .sorted { $0.updatedAt > $1.updatedAt }
            .map { tracked in
                CLISessionSummary(
                    id: tracked.sessionId,
                    state: tracked.state,
                    title: tracked.title,
                    summary: tracked.summary,
                    sensitivity: tracked.sensitivity,
                    tool: tracked.tool
                )
            }

        let primary = pickPrimary(summaries: summaries)
        let activeTool = primary?.tool ?? .unknown

        latestSnapshot = StateSnapshot(
            schemaVersion: latestSnapshot.schemaVersion,
            kind: "state.snapshot",
            updatedAt: updatedAt,
            activeTool: activeTool,
            connectionState: connectionState,
            session: primary,
            sessions: summaries,
            approval: deriveApproval(from: primary, sessions: summaries),
            healthSummary: latestSnapshot.healthSummary
        )
    }

    func pickPrimary(summaries: [CLISessionSummary]) -> CLISessionSummary? {
        guard !summaries.isEmpty else { return nil }
        return summaries.max { lhs, rhs in
            sessionPriority(lhs.state) < sessionPriority(rhs.state)
        }
    }

    func sessionPriority(_ state: SessionState) -> Int {
        switch state {
        case .waitingForApproval: return 8
        case .failed: return 7
        case .waitingForInput: return 6
        case .running: return 4
        case .completed: return 2
        case .idle: return 1
        case .unknown: return 0
        }
    }

    func deriveApproval(from primary: CLISessionSummary?, sessions: [CLISessionSummary]) -> ApprovalRequestSummary? {
        guard let primary, primary.state == .waitingForApproval else { return nil }
        return ApprovalRequestSummary(
            id: "approval-\(primary.id)",
            sessionId: primary.id,
            title: primary.title,
            summary: primary.summary,
            sensitivity: primary.sensitivity,
            expiresAt: primary.updatedAtPlus(seconds: 100)
        )
    }
}

private func parseSensitivity(_ raw: PayloadSensitivity) -> PayloadSensitivity {
    raw
}

private extension CLISessionSummary {
    func updatedAtPlus(seconds: TimeInterval) -> Date {
        Date().addingTimeInterval(seconds)
    }
}
