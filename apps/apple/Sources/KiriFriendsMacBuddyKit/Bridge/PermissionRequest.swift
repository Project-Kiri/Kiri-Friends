// PermissionRequest.swift
// Wire shape for blocking permission requests received from Claude Code,
// Codex, CodeBuddy, opencode, Pi, and other agents that support synchronous
// approval. Phase 1 only models the wire envelope; the actual approval
// bubble UI ships with Phase 5. In the interim the bridge declines so the
// agent falls back to its native prompt.

import Foundation

public struct PermissionRequest: Codable, Sendable, Hashable {
    public var toolName: String
    public var sessionId: String
    public var agentId: String?
    public var turnId: String?
    public var toolInputDescription: String?
    public var cwd: String?

    public init(
        toolName: String,
        sessionId: String,
        agentId: String? = nil,
        turnId: String? = nil,
        toolInputDescription: String? = nil,
        cwd: String? = nil
    ) {
        self.toolName = toolName
        self.sessionId = sessionId
        self.agentId = agentId
        self.turnId = turnId
        self.toolInputDescription = toolInputDescription
        self.cwd = cwd
    }

    private enum CodingKeys: String, CodingKey {
        case toolName = "tool_name"
        case sessionId = "session_id"
        case agentId = "agent_id"
        case turnId = "turn_id"
        case toolInputDescription = "tool_input_description"
        case cwd
    }
}

public struct PermissionResponse: Codable, Sendable, Hashable {
    public enum Behavior: String, Codable, Sendable, Hashable {
        case allow
        case deny
        case ask
    }

    public var behavior: Behavior?
    public var message: String?

    public init(behavior: Behavior? = nil, message: String? = nil) {
        self.behavior = behavior
        self.message = message
    }

    /// Default response when the bridge cannot decide. Clawd ships an
    /// empty JSON body so the agent falls back to its built-in approval
    /// prompt; we mirror that behavior verbatim.
    public static let decline = PermissionResponse()
}
