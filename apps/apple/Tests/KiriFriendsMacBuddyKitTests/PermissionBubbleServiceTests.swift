// PermissionBubbleServiceTests.swift
// Locks in the actor that bridges blocking HTTP permission requests to
// the bubble UI.

import Foundation
import KiriFriendsMacBuddyKit
import Testing

@Suite("PermissionBubbleService")
struct PermissionBubbleServiceTests {
    @Test("Awaiting a decision resolves once decide() runs")
    func awaitingResolves() async throws {
        let service = PermissionBubbleService()
        let request = PermissionRequest(toolName: "Bash", sessionId: "s")

        let waitTask = Task { @Sendable in
            await service.awaitDecision(for: request, agent: .claudeCode, timeout: .seconds(2))
        }

        // Wait a short moment for the service to enqueue the request,
        // then decide on the first one we see.
        try await Task.sleep(for: .milliseconds(50))
        let pending = await service.snapshot()
        let id = try #require(pending.first?.id)
        await service.decide(id: id, response: PermissionResponse(behavior: .deny))

        let response = await waitTask.value
        #expect(response.behavior == .deny)
    }

    @Test("Timeout falls back to decline")
    func timeoutResolvesAsDecline() async {
        let service = PermissionBubbleService()
        let request = PermissionRequest(toolName: "Bash", sessionId: "s")
        let response = await service.awaitDecision(
            for: request,
            agent: .claudeCode,
            timeout: .milliseconds(80)
        )
        #expect(response.behavior == nil)
    }

    @Test("Events stream surfaces added and dismissed lifecycle")
    func eventsLifecycle() async throws {
        let service = PermissionBubbleService()
        let stream = await service.events()
        var iterator = stream.makeAsyncIterator()

        let request = PermissionRequest(toolName: "Bash", sessionId: "s")
        let waitTask = Task { @Sendable in
            await service.awaitDecision(for: request, agent: .codex, timeout: .seconds(2))
        }

        let added = await iterator.next()
        if case let .added(bubble) = added {
            await service.decide(id: bubble.id, response: PermissionResponse(behavior: .allow))
        } else {
            Issue.record("Expected .added event")
            return
        }

        let dismissed = await iterator.next()
        switch dismissed {
        case .dismissed:
            break
        default:
            Issue.record("Expected .dismissed event")
        }

        _ = await waitTask.value
    }
}
