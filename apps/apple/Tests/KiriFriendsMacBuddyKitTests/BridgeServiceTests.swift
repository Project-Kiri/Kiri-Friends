// BridgeServiceTests.swift
// End-to-end smoke tests for the bridge HTTP surface. The server runs on
// a real loopback socket; the test resolves the bound port from the
// service and exercises the public routes.

import Foundation
import KiriFriendsMacBuddyKit
import Testing

@Suite("BridgeService routes")
struct BridgeServiceTests {
    @Test("Healthz returns 200 with the schema version")
    func healthzReturnsOK() async throws {
        let bridge = BridgeService(configuration: testConfiguration())
        try await bridge.start()
        defer { Task { await bridge.stop() } }

        let port = try #require(await bridge.boundPort())
        let response = try await get(path: "/healthz", port: port)
        #expect(response.statusCode == 200)
        let parsed = try JSONSerialization.jsonObject(with: response.body) as? [String: String]
        #expect(parsed?["status"] == "ok")
        #expect(parsed?["schemaVersion"] == "1")
    }

    @Test("Plugin event applies to the state store")
    func pluginEventApplies() async throws {
        let bridge = BridgeService(configuration: testConfiguration())
        try await bridge.start()
        defer { Task { await bridge.stop() } }

        let port = try #require(await bridge.boundPort())
        let envelope = PluginEventEnvelope(
            tool: AgentIdentifier.claudeCode.rawValue,
            event: .promptSubmitted,
            sessionId: "test-session",
            createdAt: "2026-05-17T00:00:00Z"
        )
        let body = try JSONEncoder().encode(envelope)
        let response = try await post(path: "/v1/plugin-events", port: port, body: body)
        #expect(response.statusCode == 204)

        let snapshot = await bridge.store.currentSnapshot()
        #expect(snapshot.displayState == .thinking)
        #expect(snapshot.sessions.first?.key.sessionId == "test-session")
    }

    @Test("Legacy state request maps the raw state")
    func legacyStateApplies() async throws {
        let bridge = BridgeService(configuration: testConfiguration())
        try await bridge.start()
        defer { Task { await bridge.stop() } }

        let port = try #require(await bridge.boundPort())
        let body = Data(#"""
        {"state":"working","session_id":"legacy","event":"PreToolUse","agent_id":"claude-code","cwd":"/tmp"}
        """#.utf8)
        let response = try await post(path: "/state", port: port, body: body)
        #expect(response.statusCode == 204)

        let snapshot = await bridge.store.currentSnapshot()
        #expect(snapshot.displayState == .working)
        #expect(snapshot.sessions.first?.cwd == "/tmp")
    }

    @Test("Permission route blocks until the bubble service decides")
    func permissionBubbleResolvesDecision() async throws {
        let bridge = BridgeService(configuration: testConfiguration())
        try await bridge.start()
        defer { Task { await bridge.stop() } }

        let port = try #require(await bridge.boundPort())
        let permissions = bridge.permissions

        // Watch for the first added bubble and auto-allow it. The
        // service emits events as async-stream values; we forward the
        // first request id back to the bubble.
        let decisionTask = Task { @Sendable in
            let stream = await permissions.events()
            for await event in stream {
                if case let .added(request) = event {
                    await permissions.decide(id: request.id, response: PermissionResponse(behavior: .allow))
                    return
                }
            }
        }

        let body = Data(#"""
        {"tool_name":"Bash","session_id":"approval","agent_id":"claude-code"}
        """#.utf8)
        let response = try await post(path: "/permission", port: port, body: body)
        decisionTask.cancel()

        #expect(response.statusCode == 200)
        let parsed = try JSONSerialization.jsonObject(with: response.body) as? [String: String]
        #expect(parsed?["behavior"] == "allow")
    }

    @Test("DND mode declines permission requests immediately")
    func dndDeclinesPermission() async throws {
        let dnd = DoNotDisturbState(initial: true)
        let bridge = BridgeService(configuration: testConfiguration(), dnd: dnd)
        try await bridge.start()
        defer { Task { await bridge.stop() } }

        let port = try #require(await bridge.boundPort())
        let body = Data(#"""
        {"tool_name":"Bash","session_id":"approval","agent_id":"claude-code"}
        """#.utf8)
        let response = try await post(path: "/permission", port: port, body: body)
        #expect(response.statusCode == 200)
        let parsed = try JSONSerialization.jsonObject(with: response.body) as? [String: Any]
        #expect(parsed?.isEmpty == true)
    }

    @Test("Unknown route yields 404")
    func unknownRoute() async throws {
        let bridge = BridgeService(configuration: testConfiguration())
        try await bridge.start()
        defer { Task { await bridge.stop() } }

        let port = try #require(await bridge.boundPort())
        let response = try await get(path: "/does-not-exist", port: port)
        #expect(response.statusCode == 404)
    }

    private func testConfiguration() -> BridgeService.Configuration {
        // Use the high-numbered ephemeral range so concurrent test runs do
        // not collide with a developer-launched bridge.
        BridgeService.Configuration(
            server: HTTPServer.Configuration(
                preferredPort: ephemeralPort(),
                portFallbacks: (0..<6).map { _ in ephemeralPort() }
            )
        )
    }

    private func ephemeralPort() -> UInt16 {
        UInt16.random(in: 49_152...65_500)
    }

    struct HTTPClientResponse: Sendable {
        let statusCode: Int
        let body: Data
    }

    private func post(path: String, port: UInt16, body: Data) async throws -> HTTPClientResponse {
        let url = try #require(URL(string: "http://127.0.0.1:\(port)\(path)"))
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.httpBody = body
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        let (data, urlResponse) = try await URLSession.shared.data(for: request)
        let http = urlResponse as! HTTPURLResponse
        return HTTPClientResponse(statusCode: http.statusCode, body: data)
    }

    private func get(path: String, port: UInt16) async throws -> HTTPClientResponse {
        let url = try #require(URL(string: "http://127.0.0.1:\(port)\(path)"))
        let (data, urlResponse) = try await URLSession.shared.data(from: url)
        let http = urlResponse as! HTTPURLResponse
        return HTTPClientResponse(statusCode: http.statusCode, body: data)
    }
}
