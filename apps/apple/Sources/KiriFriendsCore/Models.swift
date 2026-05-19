import Foundation

public enum CLITool: String, Codable, Hashable, Sendable, CaseIterable {
    case claudeCode = "claude-code"
    case codex
    case copilotCli = "copilot-cli"
    case geminiCli = "gemini-cli"
    case cursorAgent = "cursor-agent"
    case codebuddy
    case kiroCli = "kiro-cli"
    case kimiCli = "kimi-cli"
    case opencode
    case pi
    case openclaw
    case hermes
    case unknown

    /// Decodes unknown raw values as `.unknown` so newly added agents
    /// roll over to the placeholder without dropping the surrounding
    /// snapshot. Mirrors the upstream pattern in
    /// `KiriFriendsMacBuddyKit/AgentIdentifier.swift`.
    public init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        let rawValue = try container.decode(String.self)
        self = CLITool(rawValue: rawValue) ?? .unknown
    }

    /// Human-friendly label used in the Watch / iPhone surfaces.
    public var displayName: String {
        switch self {
        case .claudeCode: return "Claude Code"
        case .codex: return "Codex CLI"
        case .copilotCli: return "Copilot CLI"
        case .geminiCli: return "Gemini CLI"
        case .cursorAgent: return "Cursor Agent"
        case .codebuddy: return "CodeBuddy"
        case .kiroCli: return "Kiro CLI"
        case .kimiCli: return "Kimi CLI"
        case .opencode: return "OpenCode"
        case .pi: return "Pi"
        case .openclaw: return "OpenClaw"
        case .hermes: return "Hermes Agent"
        case .unknown: return "Unknown"
        }
    }

    /// SF Symbol used as an agent badge on the Watch and iPhone. Picked
    /// to be visually distinct across the twelve agents while remaining
    /// glanceable on a 41mm watch.
    public var symbolName: String {
        switch self {
        case .claudeCode: return "sparkles"
        case .codex: return "command"
        case .copilotCli: return "paperplane.fill"
        case .geminiCli: return "diamond.fill"
        case .cursorAgent: return "cursorarrow"
        case .codebuddy: return "person.2.fill"
        case .kiroCli: return "circle.grid.cross"
        case .kimiCli: return "moon.stars.fill"
        case .opencode: return "chevron.left.forwardslash.chevron.right"
        case .pi: return "infinity"
        case .openclaw: return "hand.raised.fingers.spread"
        case .hermes: return "bolt.horizontal.fill"
        case .unknown: return "questionmark.circle"
        }
    }
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

public struct CLISessionSummary: Codable, Hashable, Sendable, Identifiable {
    public var id: String
    public var state: SessionState
    public var title: String
    public var summary: String
    public var sensitivity: PayloadSensitivity
    public var tool: CLITool?

    public init(
        id: String,
        state: SessionState,
        title: String,
        summary: String,
        sensitivity: PayloadSensitivity,
        tool: CLITool? = nil
    ) {
        self.id = id
        self.state = state
        self.title = title
        self.summary = summary
        self.sensitivity = sensitivity
        self.tool = tool
    }

    private enum CodingKeys: String, CodingKey {
        case id
        case state
        case title
        case summary
        case sensitivity
        case tool
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.id = try container.decode(String.self, forKey: .id)
        self.state = try container.decode(SessionState.self, forKey: .state)
        self.title = try container.decode(String.self, forKey: .title)
        self.summary = try container.decode(String.self, forKey: .summary)
        self.sensitivity = try container.decode(PayloadSensitivity.self, forKey: .sensitivity)
        // Older snapshots written before the multi-agent expansion do
        // not carry a `tool` per session, so this field is optional.
        self.tool = try container.decodeIfPresent(CLITool.self, forKey: .tool)
    }
}

public struct StateSnapshot: Codable, Hashable, Sendable {
    public var schemaVersion: Int
    public var kind: String
    public var updatedAt: Date
    public var activeTool: CLITool
    public var connectionState: ConnectionState
    public var session: CLISessionSummary?
    public var sessions: [CLISessionSummary]
    public var approval: ApprovalRequestSummary?
    public var healthSummary: HealthSignalSummary?

    public init(
        schemaVersion: Int = 1,
        kind: String = "state.snapshot",
        updatedAt: Date,
        activeTool: CLITool,
        connectionState: ConnectionState,
        session: CLISessionSummary?,
        sessions: [CLISessionSummary] = [],
        approval: ApprovalRequestSummary? = nil,
        healthSummary: HealthSignalSummary? = nil
    ) {
        self.schemaVersion = schemaVersion
        self.kind = kind
        self.updatedAt = updatedAt
        self.activeTool = activeTool
        self.connectionState = connectionState
        self.session = session
        self.sessions = sessions
        self.approval = approval
        self.healthSummary = healthSummary
    }

    private enum CodingKeys: String, CodingKey {
        case schemaVersion
        case kind
        case updatedAt
        case activeTool
        case connectionState
        case session
        case sessions
        case approval
        case healthSummary
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.schemaVersion = try container.decode(Int.self, forKey: .schemaVersion)
        self.kind = try container.decode(String.self, forKey: .kind)
        self.updatedAt = try container.decode(Date.self, forKey: .updatedAt)
        self.activeTool = try container.decode(CLITool.self, forKey: .activeTool)
        self.connectionState = try container.decode(ConnectionState.self, forKey: .connectionState)
        self.session = try container.decodeIfPresent(CLISessionSummary.self, forKey: .session)
        // Backwards compatibility: snapshots predating the multi-session
        // expansion omit this array.
        self.sessions = try container.decodeIfPresent([CLISessionSummary].self, forKey: .sessions) ?? []
        self.approval = try container.decodeIfPresent(ApprovalRequestSummary.self, forKey: .approval)
        self.healthSummary = try container.decodeIfPresent(HealthSignalSummary.self, forKey: .healthSummary)
    }

    /// Count of additional sessions beyond the primary one; helpful for
    /// the Watch HUD's "+N" badge and the complication detail line.
    public var additionalSessionCount: Int {
        let primaryID = session?.id
        let others = sessions.filter { $0.id != primaryID }
        return others.count
    }

    public static let empty = StateSnapshot(
        updatedAt: Date(timeIntervalSince1970: 0),
        activeTool: .unknown,
        connectionState: .unknown,
        session: nil
    )

    public static let placeholder = StateSnapshot(
        updatedAt: Date(timeIntervalSince1970: 1_779_020_400),
        activeTool: .codex,
        connectionState: .relayConnected,
        session: CLISessionSummary(
            id: "session-uuid",
            state: .waitingForApproval,
            title: "Run tests",
            summary: "Approval required",
            sensitivity: .preview,
            tool: .codex
        ),
        sessions: [
            CLISessionSummary(
                id: "session-uuid",
                state: .waitingForApproval,
                title: "Run tests",
                summary: "Approval required",
                sensitivity: .preview,
                tool: .codex
            ),
        ],
        approval: ApprovalRequestSummary(
            id: "approval-uuid",
            sessionId: "session-uuid",
            title: "Approve CLI action?",
            summary: "Run tests",
            sensitivity: .preview,
            expiresAt: Date(timeIntervalSince1970: 1_779_020_412)
        ),
        healthSummary: .placeholder
    )
}

public enum WatchActionKind: String, Codable, Hashable, Sendable {
    case statusRefresh = "status.refresh"
    case taskStop = "task.stop"
    case approvalAllow = "approval.allow"
    case approvalDeny = "approval.deny"
    case promptSendQuick = "prompt.sendQuick"
    case voiceInputRequest = "voice.inputRequest"
}

public struct BuddySettings: Codable, Hashable, Sendable {
    public var kind: String
    public var activeManifestId: String
    public var buddyName: String
    public var showsPreviewText: Bool
    public var sharesAgentHealthContext: Bool

    public init(
        kind: String = "buddy.settings",
        activeManifestId: String,
        buddyName: String,
        showsPreviewText: Bool,
        sharesAgentHealthContext: Bool
    ) {
        self.kind = kind
        self.activeManifestId = activeManifestId
        self.buddyName = buddyName
        self.showsPreviewText = showsPreviewText
        self.sharesAgentHealthContext = sharesAgentHealthContext
    }
}

public struct WatchAction: Codable, Hashable, Sendable {
    public var schemaVersion: Int
    public var kind: String
    public var action: WatchActionKind
    public var sessionId: String?
    public var approvalId: String?
    public var text: String?
    public var createdAt: Date

    public init(
        schemaVersion: Int = 1,
        kind: String = "watch.action",
        action: WatchActionKind,
        sessionId: String?,
        approvalId: String?,
        text: String? = nil,
        createdAt: Date
    ) {
        self.schemaVersion = schemaVersion
        self.kind = kind
        self.action = action
        self.sessionId = sessionId
        self.approvalId = approvalId
        self.text = text
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

public enum BuddyPersonaState: String, Codable, Hashable, Sendable, CaseIterable {
    case sleep
    case idle
    case running
    case attention
    case celebrate
    case dizzy
    case heart
    case failed

    /// Convenience projector for the richer Mac Buddy state vocabulary.
    /// The Watch and iPhone surfaces consume the narrower persona set;
    /// this initializer keeps the projection rule co-located with the
    /// type the consumers use. Matches `MacBuddyState.personaProjection`
    /// in `KiriFriendsMacBuddyKit/MacBuddyState.swift`.
    public init(macBuddyStateRawValue rawValue: String) {
        switch rawValue {
        case "sleeping", "yawning", "dozing", "collapsing", "waking":
            self = .sleep
        case "idle":
            self = .idle
        case "thinking", "working", "juggling", "carrying", "sweeping":
            self = .running
        case "attention":
            self = .celebrate
        case "notification":
            self = .attention
        case "error":
            self = .failed
        default:
            self = .idle
        }
    }
}

public enum BuddyMood: String, Codable, Hashable, Sendable {
    case calm
    case focused
    case excited
    case concerned
    case tired
}

public enum BuddyEnergy: String, Codable, Hashable, Sendable {
    case low
    case steady
    case high
}

public struct BuddySpeechLine: Codable, Hashable, Sendable {
    public var text: String
    public var sensitivity: PayloadSensitivity

    public init(text: String, sensitivity: PayloadSensitivity) {
        self.text = text
        self.sensitivity = sensitivity
    }
}

public struct BuddyStats: Codable, Hashable, Sendable {
    public var approvals: Int
    public var denials: Int
    public var medianApprovalSeconds: Double?
    public var completedTasksToday: Int

    public init(
        approvals: Int = 0,
        denials: Int = 0,
        medianApprovalSeconds: Double? = nil,
        completedTasksToday: Int = 0
    ) {
        self.approvals = approvals
        self.denials = denials
        self.medianApprovalSeconds = medianApprovalSeconds
        self.completedTasksToday = completedTasksToday
    }
}

public struct BuddyPresentation: Codable, Hashable, Sendable {
    public var state: BuddyPersonaState
    public var mood: BuddyMood
    public var energy: BuddyEnergy
    public var speech: BuddySpeechLine
    public var primaryAction: WatchActionKind?
    public var isSensitive: Bool

    public init(
        state: BuddyPersonaState,
        mood: BuddyMood,
        energy: BuddyEnergy,
        speech: BuddySpeechLine,
        primaryAction: WatchActionKind?,
        isSensitive: Bool
    ) {
        self.state = state
        self.mood = mood
        self.energy = energy
        self.speech = speech
        self.primaryAction = primaryAction
        self.isSensitive = isSensitive
    }
}

public struct ApprovalRequestSummary: Codable, Hashable, Sendable {
    public var id: String
    public var sessionId: String
    public var title: String
    public var summary: String
    public var sensitivity: PayloadSensitivity
    public var expiresAt: Date

    public init(
        id: String,
        sessionId: String,
        title: String,
        summary: String,
        sensitivity: PayloadSensitivity,
        expiresAt: Date
    ) {
        self.id = id
        self.sessionId = sessionId
        self.title = title
        self.summary = summary
        self.sensitivity = sensitivity
        self.expiresAt = expiresAt
    }
}

public enum HealthActivityState: String, Codable, Hashable, Sendable {
    case resting
    case focused
    case active
    case elevated
    case stressed
    case unavailable
}

public struct HealthSignalSummary: Codable, Hashable, Sendable {
    public var kind: String
    public var activityState: HealthActivityState
    public var energyLevel: Int
    public var stressLevel: Int
    public var confidence: Double
    public var capturedAt: Date

    public init(
        kind: String = "health.signal.summary",
        activityState: HealthActivityState,
        energyLevel: Int,
        stressLevel: Int,
        confidence: Double,
        capturedAt: Date
    ) {
        self.kind = kind
        self.activityState = activityState
        self.energyLevel = energyLevel
        self.stressLevel = stressLevel
        self.confidence = confidence
        self.capturedAt = capturedAt
    }

    public static let placeholder = HealthSignalSummary(
        activityState: .focused,
        energyLevel: 2,
        stressLevel: 1,
        confidence: 0.7,
        capturedAt: Date(timeIntervalSince1970: 1_779_020_400)
    )
}

public struct BuddyAssetManifest: Codable, Hashable, Sendable {
    public var schemaVersion: Int
    public var identifier: String
    public var displayName: String
    public var version: String
    public var author: String?
    public var thumbnail: String?
    public var states: [BuddyPersonaState: [String]]

    public init(
        schemaVersion: Int = 1,
        identifier: String,
        displayName: String,
        version: String,
        author: String? = nil,
        thumbnail: String? = nil,
        states: [BuddyPersonaState: [String]]
    ) {
        self.schemaVersion = schemaVersion
        self.identifier = identifier
        self.displayName = displayName
        self.version = version
        self.author = author
        self.thumbnail = thumbnail
        self.states = states
    }

    public var missingRequiredStates: [BuddyPersonaState] {
        BuddyPersonaState.allCases.filter { states[$0, default: []].isEmpty }
    }

    private enum CodingKeys: String, CodingKey {
        case schemaVersion
        case identifier
        case displayName
        case version
        case author
        case thumbnail
        case states
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.schemaVersion = try container.decode(Int.self, forKey: .schemaVersion)
        self.identifier = try container.decode(String.self, forKey: .identifier)
        self.displayName = try container.decode(String.self, forKey: .displayName)
        self.version = try container.decode(String.self, forKey: .version)
        self.author = try container.decodeIfPresent(String.self, forKey: .author)
        self.thumbnail = try container.decodeIfPresent(String.self, forKey: .thumbnail)

        let rawStates = try container.decode([String: [String]].self, forKey: .states)
        self.states = Dictionary(
            uniqueKeysWithValues: rawStates.compactMap { key, value in
                guard let state = BuddyPersonaState(rawValue: key) else { return nil }
                return (state, value)
            }
        )
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(schemaVersion, forKey: .schemaVersion)
        try container.encode(identifier, forKey: .identifier)
        try container.encode(displayName, forKey: .displayName)
        try container.encode(version, forKey: .version)
        try container.encodeIfPresent(author, forKey: .author)
        try container.encodeIfPresent(thumbnail, forKey: .thumbnail)

        let rawStates = Dictionary(
            uniqueKeysWithValues: states.map { state, files in
                (state.rawValue, files)
            }
        )
        try container.encode(rawStates, forKey: .states)
    }
}

public struct WatchEvent: Codable, Hashable, Sendable {
    public var id: UUID
    public var name: String
    public var createdAt: Date
    public var payload: [String: String]

    public init(id: UUID = UUID(), name: String, createdAt: Date, payload: [String: String]) {
        self.id = id
        self.name = name
        self.createdAt = createdAt
        self.payload = payload
    }
}

public struct ComplicationSnapshot: Codable, Hashable, Sendable {
    public var updatedAt: Date
    public var shortStatus: String
    public var detail: String?
    public var symbolName: String
    public var sensitivity: PayloadSensitivity

    public init(
        updatedAt: Date,
        shortStatus: String,
        detail: String?,
        symbolName: String,
        sensitivity: PayloadSensitivity
    ) {
        self.updatedAt = updatedAt
        self.shortStatus = shortStatus
        self.detail = detail
        self.symbolName = symbolName
        self.sensitivity = sensitivity
    }

    public static let placeholder = ComplicationSnapshot(
        updatedAt: Date(timeIntervalSince1970: 1_779_020_400),
        shortStatus: "Approval",
        detail: "Kiri needs you",
        symbolName: "sparkles",
        sensitivity: .none
    )

    public static let empty = ComplicationSnapshot(
        updatedAt: Date(timeIntervalSince1970: 0),
        shortStatus: "Waiting",
        detail: "Open Kiri",
        symbolName: "sparkles",
        sensitivity: .none
    )
}
