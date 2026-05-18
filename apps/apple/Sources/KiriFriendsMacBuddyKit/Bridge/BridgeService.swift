// BridgeService.swift
// Top-level facade that wires the HTTP listener, the Mac Buddy state
// store, and the Cloud Relay uplink. Hosts the route handlers that turn
// plugin event envelopes and legacy state requests into state-store
// mutations.

import Foundation
import KiriFriendsCore

public actor BridgeService {
    public struct Configuration: Sendable {
        public var server: HTTPServer.Configuration
        public var relay: RelayUplinkClient.Configuration

        public init(
            server: HTTPServer.Configuration = HTTPServer.Configuration(),
            relay: RelayUplinkClient.Configuration = RelayUplinkClient.Configuration()
        ) {
            self.server = server
            self.relay = relay
        }
    }

    // The state store, relay client, permission bubble service, and
    // DND flag are actors with their own isolation, so it's safe to
    // expose them outside the bridge's isolation boundary. Marking
    // them nonisolated lets callers dispatch directly to those actors
    // without bouncing through the bridge's serial queue.
    public nonisolated let store: MacBuddyStateStore
    public nonisolated let relay: RelayUplinkClient
    public nonisolated let permissions: PermissionBubbleService
    public nonisolated let dnd: DoNotDisturbState

    private let configuration: Configuration
    private let server: HTTPServer
    private var pendingRequestTask: Task<Void, Never>?

    public init(
        configuration: Configuration = Configuration(),
        store: MacBuddyStateStore = MacBuddyStateStore(),
        permissions: PermissionBubbleService = PermissionBubbleService(),
        dnd: DoNotDisturbState = DoNotDisturbState(),
        relayTransport: (any RelayTransport)? = nil
    ) {
        self.configuration = configuration
        self.store = store
        self.permissions = permissions
        self.dnd = dnd
        self.relay = RelayUplinkClient(configuration: configuration.relay, transport: relayTransport)

        var router = HTTPRouter()
        let routeContext = BridgeRouteContext(store: store, relay: relay, permissions: permissions, dnd: dnd)
        router.register(method: "GET", path: "/healthz") { request in
            await BridgeRoutes.healthz(request: request, context: routeContext)
        }
        router.register(method: "POST", path: "/v1/plugin-events") { request in
            await BridgeRoutes.pluginEvents(request: request, context: routeContext)
        }
        router.register(method: "POST", path: "/state") { request in
            await BridgeRoutes.legacyState(request: request, context: routeContext)
        }
        router.register(method: "POST", path: "/permission") { request in
            await BridgeRoutes.permission(request: request, context: routeContext)
        }
        self.server = HTTPServer(configuration: configuration.server, router: router)
    }

    public func start() async throws {
        try await server.start()
        startPendingRequestLoop()
    }

    public func stop() async {
        pendingRequestTask?.cancel()
        pendingRequestTask = nil
        await server.stop()
    }

    public func boundPort() async -> UInt16? {
        await server.boundPort()
    }

    public func processPendingRequestsForTesting() async {
        await processPendingRequestsOnce()
    }

    private func startPendingRequestLoop() {
        pendingRequestTask?.cancel()
        pendingRequestTask = Task { [weak self, relay, interval = configuration.relay.pendingPollInterval] in
            while !Task.isCancelled {
                await self?.processPendingRequestsOnce()
                try? await Task.sleep(for: interval)
            }
            _ = relay
        }
    }

    private func processPendingRequestsOnce() async {
        let requests = await relay.pendingRequests()
        for request in requests {
            await handlePendingRequest(request)
        }
    }

    private func handlePendingRequest(_ request: RelayPendingRequest) async {
        await relay.acknowledge(requestId: request.requestId, status: .accepted)
        do {
            let result = try await executePendingRequest(request)
            await relay.acknowledge(requestId: request.requestId, status: .completed, result: result)
        } catch {
            await relay.acknowledge(requestId: request.requestId, status: .failed, error: "\(error)")
        }
    }

    private func executePendingRequest(_ request: RelayPendingRequest) async throws -> PluginEventPayload {
        switch request.kind {
        case WatchActionKind.statusRefresh.rawValue:
            let snapshot = await store.currentSnapshot()
            return PluginEventPayload(values: [
                "displayState": .string(snapshot.displayState.rawValue),
                "sessions": .int(snapshot.sessions.count),
            ])
        case WatchActionKind.approvalAllow.rawValue, WatchActionKind.approvalDeny.rawValue:
            let agent = await resolveAgent(for: request)
            await store.setPermissionLocked(false)
            _ = await store.apply(event: MacBuddyStateEvent(
                agent: agent,
                sessionId: request.sessionId ?? request.payload["sessionId"]?.stringValue ?? "default",
                event: "WatchAction/\(request.kind)",
                resolvedState: request.kind == WatchActionKind.approvalAllow.rawValue ? .attention : .idle
            ))
            return PluginEventPayload(values: [
                "decision": .string(request.kind == WatchActionKind.approvalAllow.rawValue ? "allow" : "deny"),
            ])
        case WatchActionKind.taskStop.rawValue:
            let agent = await resolveAgent(for: request)
            await store.clearSession(BuddySessionKey(
                agent: agent,
                sessionId: request.sessionId ?? request.payload["sessionId"]?.stringValue ?? "default"
            ))
            return PluginEventPayload(values: ["stopped": .bool(true)])
        case WatchActionKind.promptSendQuick.rawValue:
            let text = request.payload["text"]?.stringValue ?? request.payload["prompt"]?.stringValue ?? ""
            return PluginEventPayload(values: [
                "queued": .bool(!text.isEmpty),
                "text": .string(text),
            ])
        default:
            throw BridgePendingRequestError.unsupportedKind(request.kind)
        }
    }

    private func resolveAgent(for request: RelayPendingRequest) async -> AgentIdentifier {
        if let raw = request.payload["tool"]?.stringValue ?? request.payload["agent"]?.stringValue,
           let agent = AgentIdentifier(rawValue: raw) {
            return agent
        }
        if let sessionId = request.sessionId ?? request.payload["sessionId"]?.stringValue {
            let snapshot = await store.currentSnapshot()
            if let match = snapshot.sessions.first(where: { $0.key.sessionId == sessionId }) {
                return match.key.agent
            }
        }
        return .claudeCode
    }
}

private enum BridgePendingRequestError: Error, Sendable {
    case unsupportedKind(String)
}

/// Per-route context. Kept as a struct so the captured closure remains
/// `@Sendable`.
struct BridgeRouteContext: Sendable {
    let store: MacBuddyStateStore
    let relay: RelayUplinkClient
    let permissions: PermissionBubbleService
    let dnd: DoNotDisturbState
}

enum BridgeRoutes {
    static func healthz(request _: HTTPRequest, context: BridgeRouteContext) async -> HTTPResponse {
        let snapshot = await context.store.currentSnapshot()
        do {
            return try .json([
                "status": "ok",
                "schemaVersion": "\(MacBuddyKit.schemaVersion)",
                "displayState": snapshot.displayState.rawValue,
                "sessions": "\(snapshot.sessions.count)",
            ])
        } catch {
            return .empty(status: 500)
        }
    }

    static func pluginEvents(request: HTTPRequest, context: BridgeRouteContext) async -> HTTPResponse {
        let envelope: PluginEventEnvelope
        do {
            envelope = try request.decodeJSON(as: PluginEventEnvelope.self)
        } catch {
            return .empty(status: 400)
        }
        guard let agent = envelope.agentIdentifier else {
            return .empty(status: 400)
        }
        let isDnd = await context.dnd.isEnabled
        if let buddyState = envelope.event.implicitBuddyState, !isDnd {
            let event = MacBuddyStateEvent(
                agent: agent,
                sessionId: envelope.sessionId ?? "default",
                event: envelope.event.rawValue,
                resolvedState: buddyState,
                cwd: envelope.cwd
            )
            await context.store.apply(event: event)
        }
        await context.relay.ingest(envelope: envelope)

        if envelope.event == .approvalRequested && isDnd {
            // DND silences the bubble. The host CLI falls back to its
            // native flow.
            do {
                return try .json(BridgeDecisionEnvelope(decision: .decline))
            } catch {
                return .empty(status: 500)
            }
        }

        if envelope.event == .approvalRequested {
            // Route the request through the bubble service. The host
            // CLI's approval timeout is 110s (matching `CODEX_PERMISSION_WAIT_MS`
            // from plugins/src/codex.ts); we award the bubble a slightly
            // shorter slot so the bridge can deliver the response before
            // the agent times out.
            let pluginPayload = PermissionRequest(
                toolName: envelope.payload["toolName"]?.stringValue ?? "(unknown)",
                sessionId: envelope.sessionId ?? "default",
                agentId: envelope.tool,
                toolInputDescription: envelope.payload["summary"]?.stringValue,
                cwd: envelope.cwd
            )
            let response = await context.permissions.awaitDecision(
                for: pluginPayload,
                agent: agent,
                timeout: .seconds(100)
            )
            let decision = BridgeDecisionEnvelope(
                decision: BridgeDecisionEnvelope.Decision(rawValue: response.behavior?.rawValue ?? "decline") ?? .decline,
                message: response.message
            )
            do {
                return try .json(decision)
            } catch {
                return .empty(status: 500)
            }
        }
        return .empty(status: 204)
    }

    static func legacyState(request: HTTPRequest, context: BridgeRouteContext) async -> HTTPResponse {
        let payload: LegacyStateRequest
        do {
            payload = try request.decodeJSON(as: LegacyStateRequest.self)
        } catch {
            return .empty(status: 400)
        }
        guard let state = payload.resolvedState, let agent = payload.resolvedAgent else {
            return .empty(status: 400)
        }
        let event = MacBuddyStateEvent(
            agent: agent,
            sessionId: payload.sessionId,
            event: payload.event ?? "legacy/\(state.rawValue)",
            resolvedState: state,
            cwd: payload.cwd,
            sourcePid: payload.sourcePid
        )
        await context.store.apply(event: event)
        return .empty(status: 204)
    }

    static func permission(request: HTTPRequest, context: BridgeRouteContext) async -> HTTPResponse {
        let payload: PermissionRequest
        do {
            payload = try request.decodeJSON(as: PermissionRequest.self)
        } catch {
            return .empty(status: 400)
        }
        let agent = payload.agentId.flatMap(AgentIdentifier.init(rawValue:)) ?? .claudeCode

        if await context.dnd.isEnabled {
            // DND short-circuits the bubble. Upstream Clawd documents
            // that this preserves the host CLI's native approval flow.
            do {
                return try .json(PermissionResponse.decline)
            } catch {
                return .empty(status: 500)
            }
        }

        // Mark the buddy as notification while a permission is pending so
        // the UI surfaces the request as soon as the bubble manager
        // emits its event.
        let event = MacBuddyStateEvent(
            agent: agent,
            sessionId: payload.sessionId,
            event: "PermissionRequest",
            resolvedState: .notification,
            cwd: payload.cwd
        )
        await context.store.apply(event: event)
        await context.store.setPermissionLocked(true)
        let response = await context.permissions.awaitDecision(
            for: payload,
            agent: agent,
            timeout: .seconds(100)
        )
        await context.store.setPermissionLocked(false)

        do {
            return try .json(response)
        } catch {
            return .empty(status: 500)
        }
    }
}
