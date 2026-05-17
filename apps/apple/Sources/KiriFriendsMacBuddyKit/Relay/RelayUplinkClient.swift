// RelayUplinkClient.swift
// Outbound HTTPS client for Cloud Relay. Phase 1 only implements the
// fire-and-forget HTTP path used to ingest plugin events; the streaming
// channel (heartbeat + downlink) lands in a later phase together with the
// approval bubble round-trip.

import Foundation

public protocol RelayTransport: Sendable {
    func post(envelope: PluginEventEnvelope) async throws
}

public struct NullRelayTransport: RelayTransport {
    public init() {}
    public func post(envelope: PluginEventEnvelope) async throws {
        // No-op transport used when the relay base URL has not been
        // configured. Keeps the bridge testable without a remote endpoint.
    }
}

public actor RelayUplinkClient {
    public struct Configuration: Sendable {
        public var baseURL: URL?
        public var deviceToken: String?
        public var requestTimeout: TimeInterval

        public init(baseURL: URL? = nil, deviceToken: String? = nil, requestTimeout: TimeInterval = 8) {
            self.baseURL = baseURL
            self.deviceToken = deviceToken
            self.requestTimeout = requestTimeout
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
}
