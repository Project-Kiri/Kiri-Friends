// PluginEvent.swift
// Wire-compatible representation of the `PluginEventEnvelope` from
// plugins/src/types.ts. The local plugin SDK POSTs these to
// `/v1/plugin-events`; the Mac bridge re-serializes them after enriching
// with bridge-side metadata before forwarding to the Cloud Relay.

import Foundation

public enum PluginEventKind: String, Codable, Sendable, Hashable, CaseIterable {
    case sessionStarted = "session.started"
    case promptSubmitted = "prompt.submitted"
    case toolStarted = "tool.started"
    case toolCompleted = "tool.completed"
    case approvalRequested = "approval.requested"
    case approvalCompleted = "approval.completed"
    case sessionWaiting = "session.waiting"
    case sessionCompleted = "session.completed"
    case sessionFailed = "session.failed"
    case sessionCompacting = "session.compacting"
    case subagentCompleted = "subagent.completed"
    case outputPreview = "output.preview"
}

public extension PluginEventKind {
    /// Maps the normalized event kind onto a Mac Buddy animation state.
    /// `output.preview` and `approval.completed` are intentionally absent
    /// because they should not perturb the displayed state directly.
    var implicitBuddyState: MacBuddyState? {
        switch self {
        case .sessionStarted: return .idle
        case .promptSubmitted: return .thinking
        case .toolStarted, .toolCompleted, .subagentCompleted: return .working
        case .approvalRequested, .sessionWaiting: return .notification
        case .sessionCompleted: return .attention
        case .sessionFailed: return .error
        case .sessionCompacting: return .sweeping
        case .approvalCompleted, .outputPreview: return nil
        }
    }
}

public struct PluginEventEnvelope: Codable, Sendable, Hashable {
    public var version: Int
    public var tool: String
    public var event: PluginEventKind
    public var sessionId: String?
    public var cwd: String?
    public var createdAt: String
    public var payload: PluginEventPayload

    public init(
        version: Int = 1,
        tool: String,
        event: PluginEventKind,
        sessionId: String? = nil,
        cwd: String? = nil,
        createdAt: String,
        payload: PluginEventPayload = PluginEventPayload()
    ) {
        self.version = version
        self.tool = tool
        self.event = event
        self.sessionId = sessionId
        self.cwd = cwd
        self.createdAt = createdAt
        self.payload = payload
    }

    public var agentIdentifier: AgentIdentifier? {
        AgentIdentifier(rawValue: tool)
    }

    public var createdAtDate: Date? {
        try? Date(createdAt, strategy: .iso8601)
    }
}

/// Loosely typed payload container that preserves arbitrary JSON received
/// from plugin scripts. The bridge re-emits this payload to the relay
/// without inspecting most fields; specific subsystems (permission
/// bubble, redaction) decode just the slice they need.
public struct PluginEventPayload: Codable, Sendable, Hashable {
    public var values: [String: PluginEventValue]

    public init(values: [String: PluginEventValue] = [:]) {
        self.values = values
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        if container.decodeNil() {
            self.values = [:]
        } else {
            self.values = try container.decode([String: PluginEventValue].self)
        }
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(values)
    }

    public subscript(key: String) -> PluginEventValue? {
        get { values[key] }
        set { values[key] = newValue }
    }
}

public indirect enum PluginEventValue: Codable, Sendable, Hashable {
    case null
    case bool(Bool)
    case int(Int)
    case double(Double)
    case string(String)
    case array([PluginEventValue])
    case object([String: PluginEventValue])

    public init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        if container.decodeNil() { self = .null; return }
        if let bool = try? container.decode(Bool.self) { self = .bool(bool); return }
        if let int = try? container.decode(Int.self) { self = .int(int); return }
        if let double = try? container.decode(Double.self) { self = .double(double); return }
        if let string = try? container.decode(String.self) { self = .string(string); return }
        if let array = try? container.decode([PluginEventValue].self) { self = .array(array); return }
        if let object = try? container.decode([String: PluginEventValue].self) { self = .object(object); return }
        throw DecodingError.dataCorruptedError(
            in: container,
            debugDescription: "Unsupported PluginEventValue payload"
        )
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        switch self {
        case .null: try container.encodeNil()
        case .bool(let value): try container.encode(value)
        case .int(let value): try container.encode(value)
        case .double(let value): try container.encode(value)
        case .string(let value): try container.encode(value)
        case .array(let value): try container.encode(value)
        case .object(let value): try container.encode(value)
        }
    }

    public var stringValue: String? {
        if case let .string(value) = self { return value }
        return nil
    }
}

public struct BridgeDecisionEnvelope: Codable, Sendable, Hashable {
    public enum Decision: String, Codable, Sendable, Hashable {
        case allow
        case deny
        case decline
    }

    public var decision: Decision
    public var message: String?

    public init(decision: Decision, message: String? = nil) {
        self.decision = decision
        self.message = message
    }
}

