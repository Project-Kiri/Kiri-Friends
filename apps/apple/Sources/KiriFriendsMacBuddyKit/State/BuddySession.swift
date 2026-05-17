// BuddySession.swift
// Single CLI session tracked by the Mac Buddy state store. Ports the
// per-session record kept inside Clawd-on-Desk's
// `.workspace/reference/clawd-on-desk/src/state.js` sessions Map.

import Foundation

public struct BuddySessionKey: Hashable, Sendable, Codable {
    public var agent: AgentIdentifier
    public var sessionId: String

    public init(agent: AgentIdentifier, sessionId: String) {
        self.agent = agent
        self.sessionId = sessionId
    }
}

public struct BuddySession: Hashable, Sendable, Codable, Identifiable {
    public var key: BuddySessionKey
    public var state: MacBuddyState
    public var headless: Bool
    public var cwd: String?
    public var lastEventAt: Date
    public var lastEventName: String?

    public init(
        key: BuddySessionKey,
        state: MacBuddyState,
        headless: Bool = false,
        cwd: String? = nil,
        lastEventAt: Date,
        lastEventName: String? = nil
    ) {
        self.key = key
        self.state = state
        self.headless = headless
        self.cwd = cwd
        self.lastEventAt = lastEventAt
        self.lastEventName = lastEventName
    }

    public var id: BuddySessionKey { key }
}
