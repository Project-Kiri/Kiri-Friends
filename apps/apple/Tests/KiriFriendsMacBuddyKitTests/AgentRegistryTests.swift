// AgentRegistryTests.swift
// Locks in the agent registry shape so future additions remain
// backwards-compatible.

import Foundation
import KiriFriendsMacBuddyKit
import Testing

@Suite("AgentRegistry")
struct AgentRegistryTests {
    @Test("All 12 documented agents are registered")
    func registryCoverage() {
        let identifiers = AgentRegistry.all.map(\.identifier)
        #expect(Set(identifiers) == Set(AgentIdentifier.allCases))
        #expect(identifiers.count == AgentIdentifier.allCases.count)
    }

    @Test("Each registered agent has a non-empty event map")
    func eventMapNotEmpty() {
        for descriptor in AgentRegistry.all {
            #expect(!descriptor.eventMap.isEmpty, "\(descriptor.identifier) has empty event map")
        }
    }

    @Test("Claude Code PreToolUse resolves to working")
    func claudeCodeEventMap() {
        let claude = AgentRegistry.descriptor(for: .claudeCode)
        #expect(claude?.state(forEvent: "PreToolUse") == .working)
        #expect(claude?.state(forEvent: "Notification") == .notification)
        #expect(claude?.state(forEvent: "WorktreeCreate") == .carrying)
    }

    @Test("Codex PermissionRequest resolves to notification")
    func codexEventMap() {
        let codex = AgentRegistry.descriptor(for: .codex)
        #expect(codex?.state(forEvent: "PermissionRequest") == .notification)
        #expect(codex?.state(forEvent: "Stop") == .attention)
        #expect(codex?.capabilities.interactiveBubble == true)
    }

    @Test("Copilot CLI uses camelCase event names")
    func copilotEventMap() {
        let copilot = AgentRegistry.descriptor(for: .copilotCli)
        #expect(copilot?.state(forEvent: "userPromptSubmitted") == .thinking)
        #expect(copilot?.state(forEvent: "preToolUse") == .working)
        #expect(copilot?.state(forEvent: "agentStop") == .attention)
        #expect(copilot?.state(forEvent: "UserPromptSubmit") == nil)
    }

    @Test("Kimi CLI surfaces both notification and permissionApproval capabilities")
    func kimiCapabilities() {
        let kimi = AgentRegistry.descriptor(for: .kimiCli)
        #expect(kimi?.capabilities.httpHook == true)
        #expect(kimi?.capabilities.permissionApproval == true)
        #expect(kimi?.capabilities.notificationHook == true)
        #expect(kimi?.capabilities.subagent == true)
    }

    @Test("Hermes only handles plugin event sources and lacks permission approval")
    func hermesCapabilities() {
        let hermes = AgentRegistry.descriptor(for: .hermes)
        #expect(hermes?.eventSource == .pluginEvent)
        #expect(hermes?.capabilities.permissionApproval == false)
    }

    @Test("Process names default to mac names on macOS")
    func processNamesPlatform() {
        let claude = AgentRegistry.descriptor(for: .claudeCode)
        #expect(claude?.processNames.current == ["claude"])
    }
}
