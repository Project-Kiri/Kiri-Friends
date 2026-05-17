// PluginEventTests.swift
// Locks in the wire-shape compatibility with plugins/src/types.ts so
// future plugin packages can encode/decode through Swift transparently.

import Foundation
import KiriFriendsMacBuddyKit
import Testing

@Suite("PluginEventEnvelope")
struct PluginEventTests {
    @Test("Round trips through JSON")
    func roundTrip() throws {
        let envelope = PluginEventEnvelope(
            tool: "claude-code",
            event: .toolStarted,
            sessionId: "sess-1",
            cwd: "/Users/dev/app",
            createdAt: "2026-05-17T22:00:00Z",
            payload: PluginEventPayload(values: [
                "hookEventName": .string("PreToolUse"),
                "toolName": .string("Bash"),
            ])
        )
        let data = try JSONEncoder().encode(envelope)
        let decoded = try JSONDecoder().decode(PluginEventEnvelope.self, from: data)
        #expect(decoded == envelope)
        #expect(decoded.agentIdentifier == .claudeCode)
    }

    @Test("Decodes a real plugin envelope shape")
    func decodesRealEnvelope() throws {
        let json = Data(#"""
        {
          "version": 1,
          "tool": "codex",
          "event": "approval.requested",
          "sessionId": "abc",
          "createdAt": "2026-05-17T22:30:00.123Z",
          "payload": {
            "toolName": "Bash",
            "summary": "Run unit tests"
          }
        }
        """#.utf8)
        let decoded = try JSONDecoder().decode(PluginEventEnvelope.self, from: json)
        #expect(decoded.tool == "codex")
        #expect(decoded.event == .approvalRequested)
        #expect(decoded.sessionId == "abc")
        #expect(decoded.payload["toolName"]?.stringValue == "Bash")
    }

    @Test("Implicit state mapping covers all event kinds with semantics")
    func implicitStateMappingCoverage() {
        let mapped: [PluginEventKind: MacBuddyState] = [
            .sessionStarted: .idle,
            .promptSubmitted: .thinking,
            .toolStarted: .working,
            .toolCompleted: .working,
            .subagentCompleted: .working,
            .approvalRequested: .notification,
            .sessionWaiting: .notification,
            .sessionCompleted: .attention,
            .sessionFailed: .error,
            .sessionCompacting: .sweeping,
        ]
        for (kind, expected) in mapped {
            #expect(kind.implicitBuddyState == expected)
        }
        #expect(PluginEventKind.approvalCompleted.implicitBuddyState == nil)
        #expect(PluginEventKind.outputPreview.implicitBuddyState == nil)
    }
}
