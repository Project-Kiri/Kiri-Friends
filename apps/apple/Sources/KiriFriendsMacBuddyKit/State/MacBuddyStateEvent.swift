// MacBuddyStateEvent.swift
// Normalized input + output value types for the Mac Buddy state machine.

import Foundation

/// Incoming event after the HTTP server has parsed the JSON body and the
/// agent registry has resolved the event name into a `MacBuddyState`.
/// Mirrors the upstream `state.js applyEventToSession` argument shape.
public struct MacBuddyStateEvent: Sendable, Hashable, Codable {
    public var agent: AgentIdentifier
    public var sessionId: String
    public var event: String
    public var resolvedState: MacBuddyState
    public var cwd: String?
    public var sourcePid: Int32?
    public var receivedAt: Date

    public init(
        agent: AgentIdentifier,
        sessionId: String,
        event: String,
        resolvedState: MacBuddyState,
        cwd: String? = nil,
        sourcePid: Int32? = nil,
        receivedAt: Date = Date()
    ) {
        self.agent = agent
        self.sessionId = sessionId
        self.event = event
        self.resolvedState = resolvedState
        self.cwd = cwd
        self.sourcePid = sourcePid
        self.receivedAt = receivedAt
    }
}

/// Snapshot of the computed display state at any point in time. The
/// `displayState` field is the priority-resolved winner; UI consumers in
/// Phase 2+ subscribe to the snapshot stream rather than the per-session
/// mutation events.
public struct MacBuddyDisplaySnapshot: Sendable, Hashable, Codable {
    public var displayState: MacBuddyState
    public var sessions: [BuddySession]
    public var permissionLocked: Bool
    public var updatedAt: Date

    public init(
        displayState: MacBuddyState,
        sessions: [BuddySession],
        permissionLocked: Bool,
        updatedAt: Date
    ) {
        self.displayState = displayState
        self.sessions = sessions
        self.permissionLocked = permissionLocked
        self.updatedAt = updatedAt
    }

    public static let sleeping = MacBuddyDisplaySnapshot(
        displayState: .sleeping,
        sessions: [],
        permissionLocked: false,
        updatedAt: Date(timeIntervalSince1970: 0)
    )
}
