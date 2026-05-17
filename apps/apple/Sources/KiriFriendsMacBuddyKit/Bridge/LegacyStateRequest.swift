// LegacyStateRequest.swift
// Wire shape produced by Clawd-on-Desk hook scripts when POSTing to the
// legacy `/state` endpoint. Phase 6 hooks reuse this shape so the bridge
// can interoperate with ports of the existing hook scripts in
// `.workspace/reference/clawd-on-desk/hooks/`.

import Foundation

public struct LegacyStateRequest: Codable, Sendable, Hashable {
    public var state: String
    public var sessionId: String
    public var event: String?
    public var agentId: String?
    public var cwd: String?
    public var sourcePid: Int32?
    public var headless: Bool?
    public var toolName: String?

    public init(
        state: String,
        sessionId: String,
        event: String? = nil,
        agentId: String? = nil,
        cwd: String? = nil,
        sourcePid: Int32? = nil,
        headless: Bool? = nil,
        toolName: String? = nil
    ) {
        self.state = state
        self.sessionId = sessionId
        self.event = event
        self.agentId = agentId
        self.cwd = cwd
        self.sourcePid = sourcePid
        self.headless = headless
        self.toolName = toolName
    }

    private enum CodingKeys: String, CodingKey {
        case state
        case sessionId = "session_id"
        case event
        case agentId = "agent_id"
        case cwd
        case sourcePid = "source_pid"
        case headless
        case toolName = "tool_name"
    }

    public var resolvedState: MacBuddyState? {
        MacBuddyState(rawValue: state)
    }

    public var resolvedAgent: AgentIdentifier? {
        agentId.flatMap(AgentIdentifier.init(rawValue:)) ?? .claudeCode
    }
}
