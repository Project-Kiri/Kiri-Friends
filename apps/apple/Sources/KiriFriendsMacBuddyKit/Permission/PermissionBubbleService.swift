// PermissionBubbleService.swift
// Routes blocking permission requests from the bridge HTTP server to a
// UI surface that can show an in-app bubble and back to the agent once
// the user decides. Ports the permission-decision flow described in
// `.workspace/reference/clawd-on-desk/src/permission.js`.

import Foundation

public struct PermissionBubbleRequest: Sendable, Hashable, Identifiable {
    public var id: UUID
    public var agent: AgentIdentifier
    public var payload: PermissionRequest
    public var createdAt: Date

    public init(id: UUID = UUID(), agent: AgentIdentifier, payload: PermissionRequest, createdAt: Date = Date()) {
        self.id = id
        self.agent = agent
        self.payload = payload
        self.createdAt = createdAt
    }
}

public struct PermissionBubbleDecision: Sendable, Hashable {
    public var id: UUID
    public var response: PermissionResponse

    public init(id: UUID, response: PermissionResponse) {
        self.id = id
        self.response = response
    }
}

public enum PermissionBubbleEvent: Sendable, Hashable {
    case added(PermissionBubbleRequest)
    case dismissed(UUID)
}

public actor PermissionBubbleService {
    private struct Pending {
        let request: PermissionBubbleRequest
        var continuation: CheckedContinuation<PermissionResponse, Never>
    }

    private var pending: [UUID: Pending] = [:]
    private var listeners: [UUID: AsyncStream<PermissionBubbleEvent>.Continuation] = [:]

    public init() {}

    public func events() -> AsyncStream<PermissionBubbleEvent> {
        AsyncStream { continuation in
            let id = UUID()
            self.installListener(id: id, continuation: continuation)
            for entry in pending.values {
                continuation.yield(.added(entry.request))
            }
            continuation.onTermination = { [weak self] _ in
                guard let self else { return }
                Task { await self.removeListener(id: id) }
            }
        }
    }

    public func snapshot() -> [PermissionBubbleRequest] {
        pending.values
            .map(\.request)
            .sorted { $0.createdAt < $1.createdAt }
    }

    /// Awaits a user decision for `request`. Returns the resolved
    /// `PermissionResponse`; the caller is responsible for converting it
    /// into the wire format expected by the host agent.
    public func awaitDecision(
        for request: PermissionRequest,
        agent: AgentIdentifier,
        timeout: Duration
    ) async -> PermissionResponse {
        let id = UUID()
        let bubble = PermissionBubbleRequest(id: id, agent: agent, payload: request)
        let response: PermissionResponse = await withCheckedContinuation { continuation in
            pending[id] = Pending(request: bubble, continuation: continuation)
            broadcast(event: .added(bubble))
            schedule(timeout: timeout, for: id)
        }
        broadcast(event: .dismissed(id))
        return response
    }

    public func decide(id: UUID, response: PermissionResponse) {
        guard let entry = pending.removeValue(forKey: id) else { return }
        entry.continuation.resume(returning: response)
    }

    public func cancel(id: UUID) {
        decide(id: id, response: .decline)
    }

    public func cancelAll() {
        for id in pending.keys {
            cancel(id: id)
        }
    }

    private func schedule(timeout: Duration, for id: UUID) {
        Task { [weak self] in
            try? await Task.sleep(for: timeout)
            await self?.cancel(id: id)
        }
    }

    private func broadcast(event: PermissionBubbleEvent) {
        for continuation in listeners.values {
            continuation.yield(event)
        }
    }

    private func installListener(id: UUID, continuation: AsyncStream<PermissionBubbleEvent>.Continuation) {
        listeners[id] = continuation
    }

    private func removeListener(id: UUID) {
        listeners.removeValue(forKey: id)
    }
}
