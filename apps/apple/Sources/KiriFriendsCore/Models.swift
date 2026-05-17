import Foundation

public enum CLITool: String, Codable, Hashable, Sendable {
    case claudeCode = "claude-code"
    case codex
    case opencode
    case unknown
}

public enum SessionState: String, Codable, Hashable, Sendable {
    case idle
    case running
    case waitingForInput
    case waitingForApproval
    case failed
    case completed
    case unknown
}

public enum ConnectionState: String, Codable, Hashable, Sendable {
    case relayConnected
    case relayUnavailable
    case macOffline
    case iphoneUnreachable
    case unknown
}

public enum PayloadSensitivity: String, Codable, Hashable, Sendable {
    case none
    case preview
    case `private`
    case secret
}

public struct CLISessionSummary: Codable, Hashable, Sendable {
    public var id: String
    public var state: SessionState
    public var title: String
    public var summary: String
    public var sensitivity: PayloadSensitivity

    public init(
        id: String,
        state: SessionState,
        title: String,
        summary: String,
        sensitivity: PayloadSensitivity
    ) {
        self.id = id
        self.state = state
        self.title = title
        self.summary = summary
        self.sensitivity = sensitivity
    }
}

public struct StateSnapshot: Codable, Hashable, Sendable {
    public var schemaVersion: Int
    public var kind: String
    public var updatedAt: Date
    public var activeTool: CLITool
    public var connectionState: ConnectionState
    public var session: CLISessionSummary?

    public init(
        schemaVersion: Int = 1,
        kind: String = "state.snapshot",
        updatedAt: Date,
        activeTool: CLITool,
        connectionState: ConnectionState,
        session: CLISessionSummary?
    ) {
        self.schemaVersion = schemaVersion
        self.kind = kind
        self.updatedAt = updatedAt
        self.activeTool = activeTool
        self.connectionState = connectionState
        self.session = session
    }

    public static let placeholder = StateSnapshot(
        updatedAt: Date(timeIntervalSince1970: 1_779_020_400),
        activeTool: .codex,
        connectionState: .relayConnected,
        session: CLISessionSummary(
            id: "session-uuid",
            state: .waitingForApproval,
            title: "Run tests",
            summary: "Approval required",
            sensitivity: .preview
        )
    )
}

public enum WatchActionKind: String, Codable, Hashable, Sendable {
    case statusRefresh = "status.refresh"
    case taskStop = "task.stop"
    case approvalAllow = "approval.allow"
    case approvalDeny = "approval.deny"
    case promptSendQuick = "prompt.sendQuick"
}

public struct WatchAction: Codable, Hashable, Sendable {
    public var schemaVersion: Int
    public var kind: String
    public var action: WatchActionKind
    public var sessionId: String?
    public var approvalId: String?
    public var createdAt: Date

    public init(
        schemaVersion: Int = 1,
        kind: String = "watch.action",
        action: WatchActionKind,
        sessionId: String?,
        approvalId: String?,
        createdAt: Date
    ) {
        self.schemaVersion = schemaVersion
        self.kind = kind
        self.action = action
        self.sessionId = sessionId
        self.approvalId = approvalId
        self.createdAt = createdAt
    }
}

public enum BridgeMessageType: String, Codable, Hashable, Sendable {
    case request
    case response
    case event
    case ack
    case heartbeat
}

public struct BridgeEndpoint: Codable, Hashable, Sendable {
    public var role: String
    public var deviceId: String?

    public init(role: String, deviceId: String? = nil) {
        self.role = role
        self.deviceId = deviceId
    }
}

public struct CLIBridgeMessage<Payload: Codable & Hashable & Sendable>: Codable, Hashable, Sendable {
    public var version: Int
    public var id: UUID
    public var correlationId: UUID?
    public var type: BridgeMessageType
    public var createdAt: Date
    public var expiresAt: Date?
    public var source: BridgeEndpoint
    public var target: BridgeEndpoint?
    public var payload: Payload

    public init(
        version: Int = 1,
        id: UUID = UUID(),
        correlationId: UUID? = nil,
        type: BridgeMessageType,
        createdAt: Date,
        expiresAt: Date? = nil,
        source: BridgeEndpoint,
        target: BridgeEndpoint? = nil,
        payload: Payload
    ) {
        self.version = version
        self.id = id
        self.correlationId = correlationId
        self.type = type
        self.createdAt = createdAt
        self.expiresAt = expiresAt
        self.source = source
        self.target = target
        self.payload = payload
    }
}

public enum BridgeErrorCode: String, Codable, Hashable, Sendable {
    case invalidRequest = "invalid_request"
    case schemaVersionUnsupported = "schema_version_unsupported"
    case notAuthenticated = "not_authenticated"
    case notAuthorized = "not_authorized"
    case targetOffline = "target_offline"
    case sessionNotFound = "session_not_found"
    case requestExpired = "request_expired"
    case adapterUnsupported = "adapter_unsupported"
    case adapterFailed = "adapter_failed"
    case rateLimited = "rate_limited"
    case payloadTooLarge = "payload_too_large"
    case internalError = "internal_error"
}

public struct BridgeError: Codable, Hashable, Sendable {
    public var code: BridgeErrorCode
    public var message: String
    public var retryable: Bool

    public init(code: BridgeErrorCode, message: String, retryable: Bool) {
        self.code = code
        self.message = message
        self.retryable = retryable
    }
}
