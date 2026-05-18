// RelayUplinkClient.swift
// Outbound HTTPS client for Cloud Relay. Phase 1 only implements the
// fire-and-forget HTTP path used to ingest plugin events; the streaming
// channel (heartbeat + downlink) lands in a later phase together with the
// approval bubble round-trip.

import Foundation

public protocol RelayTransport: Sendable {
    func post(envelope: PluginEventEnvelope) async throws
    func pendingRequests() async throws -> [RelayPendingRequest]
    func acknowledge(requestId: String, status: RelayRequestStatus, result: PluginEventPayload?, error: String?) async throws
}

public struct NullRelayTransport: RelayTransport {
    public init() {}
    public func post(envelope: PluginEventEnvelope) async throws {
        // No-op transport used when the relay base URL has not been
        // configured. Keeps the bridge testable without a remote endpoint.
    }
    public func pendingRequests() async throws -> [RelayPendingRequest] { [] }
    public func acknowledge(requestId _: String, status _: RelayRequestStatus, result _: PluginEventPayload?, error _: String?) async throws {}
}

public enum RelayRequestStatus: String, Codable, Sendable, Hashable {
    case accepted
    case completed
    case failed
    case expired
    case superseded
}

public struct RelayPendingRequest: Codable, Sendable, Hashable, Identifiable {
    public var requestId: String
    public var targetDeviceId: String
    public var sessionId: String?
    public var kind: String
    public var expiresAt: String
    public var idempotencyKey: String
    public var payload: PluginEventPayload

    public var id: String { requestId }

    public init(
        requestId: String,
        targetDeviceId: String,
        sessionId: String? = nil,
        kind: String,
        expiresAt: String,
        idempotencyKey: String,
        payload: PluginEventPayload = PluginEventPayload()
    ) {
        self.requestId = requestId
        self.targetDeviceId = targetDeviceId
        self.sessionId = sessionId
        self.kind = kind
        self.expiresAt = expiresAt
        self.idempotencyKey = idempotencyKey
        self.payload = payload
    }
}

public actor RelayUplinkClient {
    public struct Configuration: Sendable {
        public var baseURL: URL?
        public var deviceToken: String?
        public var requestTimeout: TimeInterval
        public var pendingPollInterval: Duration

        public init(
            baseURL: URL? = nil,
            deviceToken: String? = nil,
            requestTimeout: TimeInterval = 8,
            pendingPollInterval: Duration = .seconds(2)
        ) {
            self.baseURL = baseURL
            self.deviceToken = deviceToken
            self.requestTimeout = requestTimeout
            self.pendingPollInterval = pendingPollInterval
        }
    }

    private let configuration: Configuration
    private let session: URLSession
    private let transport: (any RelayTransport)?

    public init(configuration: Configuration, transport: (any RelayTransport)? = nil) {
        self.configuration = configuration
        self.transport = transport
        let sessionConfig = URLSessionConfiguration.ephemeral
        sessionConfig.timeoutIntervalForRequest = configuration.requestTimeout
        sessionConfig.timeoutIntervalForResource = configuration.requestTimeout
        sessionConfig.waitsForConnectivity = false
        self.session = URLSession(configuration: sessionConfig)
    }

    public func ingest(envelope: PluginEventEnvelope) async {
        if let transport {
            try? await transport.post(envelope: envelope)
            return
        }
        guard let baseURL = configuration.baseURL else {
            // No relay configured; the bridge runs in local-only mode.
            return
        }
        let url = baseURL.appending(path: "v1/plugin-events")
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        if let token = configuration.deviceToken {
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        guard let body = try? encoder.encode(envelope) else { return }
        request.httpBody = body
        _ = try? await session.data(for: request)
    }

    public func pendingRequests() async -> [RelayPendingRequest] {
        if let transport {
            return (try? await transport.pendingRequests()) ?? []
        }
        guard let baseURL = configuration.baseURL else { return [] }
        var request = URLRequest(url: baseURL.appending(path: "v1/requests/pending"))
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        if let token = configuration.deviceToken {
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }
        do {
            let (data, _) = try await session.data(for: request)
            struct Envelope: Decodable { var requests: [RelayPendingRequest] }
            return try JSONDecoder().decode(Envelope.self, from: data).requests
        } catch {
            return []
        }
    }

    public func acknowledge(
        requestId: String,
        status: RelayRequestStatus,
        result: PluginEventPayload? = nil,
        error: String? = nil
    ) async {
        if let transport {
            try? await transport.acknowledge(requestId: requestId, status: status, result: result, error: error)
            return
        }
        guard let baseURL = configuration.baseURL else { return }
        var request = URLRequest(url: baseURL.appending(path: "v1/requests/\(requestId)/ack"))
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        if let token = configuration.deviceToken {
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }
        struct AckBody: Encodable {
            var status: RelayRequestStatus
            var result: PluginEventPayload?
            var error: String?
        }
        request.httpBody = try? JSONEncoder().encode(AckBody(status: status, result: result, error: error))
        _ = try? await session.data(for: request)
    }
}
