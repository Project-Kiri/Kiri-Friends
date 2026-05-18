// RelayDownlinkClient.swift
// Protocol abstraction for fetching events from Cloud Relay and posting
// requests back upstream. Three implementations ship today:
//
// - `HTTPRelayDownlinkClient` polls `/v1/events` over HTTPS for live
//   deployments.
// - `InMemoryRelayDownlinkClient` is a deterministic fake used by tests
//   and explicit local-development runs.
// - `RelayUnavailableDownlinkClient` represents a real unconfigured state;
//   it never pretends to be connected.
//
// The event payload shape mirrors the `RelayEvent` returned by the
// server's `/v1/events` route in `server/src/http-server.ts`.

import Foundation
import KiriFriendsCore

public struct RelayEventEnvelope: Codable, Sendable, Hashable, Identifiable {
    public var eventId: String
    public var version: Int?
    public var userId: String
    public var sourceDeviceId: String
    public var tool: String?
    public var event: String
    public var sessionId: String?
    public var cwd: String?
    public var createdAt: Date
    public var payload: [String: RelayValue]
    public var sensitivity: PayloadSensitivity

    public var id: String { eventId }

    public init(
        eventId: String,
        version: Int? = nil,
        userId: String,
        sourceDeviceId: String,
        tool: String? = nil,
        event: String,
        sessionId: String? = nil,
        cwd: String? = nil,
        createdAt: Date,
        payload: [String: RelayValue] = [:],
        sensitivity: PayloadSensitivity = .preview
    ) {
        self.eventId = eventId
        self.version = version
        self.userId = userId
        self.sourceDeviceId = sourceDeviceId
        self.tool = tool
        self.event = event
        self.sessionId = sessionId
        self.cwd = cwd
        self.createdAt = createdAt
        self.payload = payload
        self.sensitivity = sensitivity
    }
}

public struct RelayRequestEnvelope: Codable, Sendable, Hashable {
    public var targetDeviceId: String
    public var sessionId: String?
    public var kind: String
    public var expiresAt: Date
    public var idempotencyKey: String
    public var payload: [String: RelayValue]

    public init(
        targetDeviceId: String,
        sessionId: String? = nil,
        kind: String,
        expiresAt: Date,
        idempotencyKey: String,
        payload: [String: RelayValue] = [:]
    ) {
        self.targetDeviceId = targetDeviceId
        self.sessionId = sessionId
        self.kind = kind
        self.expiresAt = expiresAt
        self.idempotencyKey = idempotencyKey
        self.payload = payload
    }
}

/// Loose JSON value container that round-trips through `JSONEncoder` /
/// `JSONDecoder`. Used so the relay payloads can carry arbitrary plugin
/// metadata without requiring a fixed schema at the bridge boundary.
public indirect enum RelayValue: Codable, Sendable, Hashable {
    case null
    case bool(Bool)
    case int(Int)
    case double(Double)
    case string(String)
    case array([RelayValue])
    case object([String: RelayValue])

    public init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        if container.decodeNil() { self = .null; return }
        if let value = try? container.decode(Bool.self) { self = .bool(value); return }
        if let value = try? container.decode(Int.self) { self = .int(value); return }
        if let value = try? container.decode(Double.self) { self = .double(value); return }
        if let value = try? container.decode(String.self) { self = .string(value); return }
        if let value = try? container.decode([RelayValue].self) { self = .array(value); return }
        if let value = try? container.decode([String: RelayValue].self) { self = .object(value); return }
        throw DecodingError.dataCorruptedError(in: container, debugDescription: "Unsupported RelayValue")
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

public protocol RelayDownlinkClient: Sendable {
    var startupConnectionState: ConnectionState { get }

    /// Streams events as they arrive. Implementations may poll, use SSE,
    /// or push from a local queue; the bridge only cares that events
    /// arrive in monotonic createdAt order.
    func streamEvents(since cursor: String?) -> AsyncStream<RelayEventEnvelope>

    /// Posts a request envelope back to the Mac bridge via Cloud Relay.
    func sendRequest(_ request: RelayRequestEnvelope) async throws
}

public struct RelayUnavailableDownlinkClient: RelayDownlinkClient {
    public enum UnavailableError: Error, LocalizedError, Sendable {
        case missingConfiguration

        public var errorDescription: String? {
            "Cloud Relay is not configured."
        }
    }

    public var startupConnectionState: ConnectionState { .relayUnavailable }

    public init() {}

    public func streamEvents(since cursor: String?) -> AsyncStream<RelayEventEnvelope> {
        AsyncStream { continuation in
            continuation.finish()
        }
    }

    public func sendRequest(_ request: RelayRequestEnvelope) async throws {
        throw UnavailableError.missingConfiguration
    }
}

// MARK: - In-memory implementation (tests)

public actor InMemoryRelayDownlinkClient: RelayDownlinkClient {
    public nonisolated var startupConnectionState: ConnectionState { .relayConnected }

    public private(set) var sentRequests: [RelayRequestEnvelope] = []
    private var continuations: [UUID: AsyncStream<RelayEventEnvelope>.Continuation] = [:]
    private var queue: [RelayEventEnvelope] = []

    public init(initialEvents: [RelayEventEnvelope] = []) {
        self.queue = initialEvents
    }

    public nonisolated func streamEvents(since cursor: String?) -> AsyncStream<RelayEventEnvelope> {
        AsyncStream { continuation in
            let id = UUID()
            Task {
                await self.attachStream(id: id, continuation: continuation, since: cursor)
            }
            continuation.onTermination = { [weak self] _ in
                guard let self else { return }
                Task { await self.removeContinuation(id: id) }
            }
        }
    }

    public func sendRequest(_ request: RelayRequestEnvelope) async throws {
        sentRequests.append(request)
    }

    public func emit(_ event: RelayEventEnvelope) {
        queue.append(event)
        for continuation in continuations.values {
            continuation.yield(event)
        }
    }

    private func attachStream(
        id: UUID,
        continuation: AsyncStream<RelayEventEnvelope>.Continuation,
        since cursor: String?
    ) {
        continuations[id] = continuation
        var startIndex = 0
        if let cursor, let cursorIndex = queue.firstIndex(where: { $0.eventId == cursor }) {
            startIndex = cursorIndex + 1
        }
        for event in queue[startIndex...] {
            continuation.yield(event)
        }
    }

    private func removeContinuation(id: UUID) {
        continuations.removeValue(forKey: id)
    }
}

// MARK: - HTTP implementation

public actor HTTPRelayDownlinkClient: RelayDownlinkClient {
    public nonisolated var startupConnectionState: ConnectionState { .relayConnected }

    public struct Configuration: Sendable {
        public var baseURL: URL
        public var deviceToken: String
        public var pollInterval: Duration
        public var userId: String?

        public init(
            baseURL: URL,
            deviceToken: String,
            pollInterval: Duration = .seconds(2),
            userId: String? = nil
        ) {
            self.baseURL = baseURL
            self.deviceToken = deviceToken
            self.pollInterval = pollInterval
            self.userId = userId
        }
    }

    private let configuration: Configuration
    private let session: URLSession

    public init(configuration: Configuration, session: URLSession = .shared) {
        self.configuration = configuration
        self.session = session
    }

    public nonisolated func streamEvents(since cursor: String?) -> AsyncStream<RelayEventEnvelope> {
        AsyncStream { continuation in
            let task = Task {
                await self.poll(continuation: continuation, since: cursor)
            }
            continuation.onTermination = { _ in task.cancel() }
        }
    }

    public func sendRequest(_ request: RelayRequestEnvelope) async throws {
        var urlRequest = URLRequest(url: configuration.baseURL.appending(path: "v1/requests"))
        urlRequest.httpMethod = "POST"
        urlRequest.setValue("Bearer \(configuration.deviceToken)", forHTTPHeaderField: "Authorization")
        urlRequest.setValue("application/json", forHTTPHeaderField: "Content-Type")
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        urlRequest.httpBody = try encoder.encode(request)
        _ = try await session.data(for: urlRequest)
    }

    private func poll(continuation: AsyncStream<RelayEventEnvelope>.Continuation, since cursor: String?) async {
        var nextCursor: String? = cursor
        while !Task.isCancelled {
            do {
                let events = try await fetchEvents(since: nextCursor)
                for event in events {
                    continuation.yield(event)
                    nextCursor = event.eventId
                }
            } catch {
                // Polling errors are surfaced via the next poll cycle;
                // the bridge tolerates transient downtime.
            }
            try? await Task.sleep(for: configuration.pollInterval)
        }
        continuation.finish()
    }

    private func fetchEvents(since cursor: String?) async throws -> [RelayEventEnvelope] {
        var components = URLComponents(
            url: configuration.baseURL.appending(path: "v1/events"),
            resolvingAgainstBaseURL: false
        )
        var queryItems: [URLQueryItem] = []
        if let userId = configuration.userId {
            queryItems.append(URLQueryItem(name: "userId", value: userId))
        }
        if let cursor {
            queryItems.append(URLQueryItem(name: "since", value: cursor))
        }
        if !queryItems.isEmpty {
            components?.queryItems = queryItems
        }
        guard let url = components?.url else { return [] }

        var request = URLRequest(url: url)
        request.setValue("Bearer \(configuration.deviceToken)", forHTTPHeaderField: "Authorization")
        let (data, _) = try await session.data(for: request)
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        struct Envelope: Decodable { let events: [RelayEventEnvelope] }
        let parsed = try decoder.decode(Envelope.self, from: data)
        return parsed.events
    }
}
