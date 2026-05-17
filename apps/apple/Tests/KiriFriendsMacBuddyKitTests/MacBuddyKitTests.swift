// MacBuddyKitTests.swift
// Phase 0 sanity coverage for MacBuddyKit. Per-phase test suites for the
// state store, HTTP server, agent registry, and theme loader land in
// subsequent phases.

import Foundation
import KiriFriendsCore
import KiriFriendsMacBuddyKit
import Testing

@Suite("MacBuddyKit Phase 0 scaffolding")
struct MacBuddyKitTests {
    @Test("Default bridge port is the documented CLIBridge fallback")
    func defaultBridgePort() {
        #expect(MacBuddyKit.defaultBridgePort == 7474)
    }

    @Test("Support directory resolves under the supplied home directory")
    func supportDirectoryResolvesUnderHome() {
        let home = URL(filePath: "/tmp/kiri-friends-test-home")
        let support = MacBuddyKit.defaultSupportDirectory(homeDirectory: home)
        #expect(support.path() == "/tmp/kiri-friends-test-home/.kirifriends/")
    }

    @Test("Every documented agent identifier is present")
    func agentIdentifierEnumCoverage() {
        let expected: Set<AgentIdentifier> = [
            .claudeCode, .codex, .copilotCli, .geminiCli, .cursorAgent,
            .codebuddy, .kiroCli, .kimiCli, .opencode, .pi, .openclaw, .hermes,
        ]
        #expect(Set(AgentIdentifier.allCases) == expected)
    }

    @Test("Mac buddy states project to a persona state")
    func macBuddyStateProjections() {
        let runningStates: [MacBuddyState] = [
            .thinking, .working, .juggling, .carrying, .sweeping,
        ]
        for state in runningStates {
            #expect(state.personaProjection == .running)
        }

        let sleepStates: [MacBuddyState] = [
            .sleeping, .yawning, .dozing, .collapsing, .waking,
        ]
        for state in sleepStates {
            #expect(state.personaProjection == .sleep)
        }

        #expect(MacBuddyState.idle.personaProjection == .idle)
        #expect(MacBuddyState.notification.personaProjection == .attention)
        #expect(MacBuddyState.attention.personaProjection == .celebrate)
        #expect(MacBuddyState.error.personaProjection == .failed)
    }

    @Test("State priorities match the upstream Clawd STATE_PRIORITY table")
    func statePriorityTable() {
        #expect(MacBuddyState.error.priority == 8)
        #expect(MacBuddyState.notification.priority == 7)
        #expect(MacBuddyState.sweeping.priority == 6)
        #expect(MacBuddyState.attention.priority == 5)
        #expect(MacBuddyState.carrying.priority == 4)
        #expect(MacBuddyState.juggling.priority == 4)
        #expect(MacBuddyState.working.priority == 3)
        #expect(MacBuddyState.thinking.priority == 2)
        #expect(MacBuddyState.idle.priority == 1)
        #expect(MacBuddyState.sleeping.priority == 0)
        for sleepState in MacBuddyState.sleepSequence {
            #expect(sleepState.priority == 0)
        }
    }

    @Test("Sleep sequence and one-shot membership match upstream sets")
    func sleepSequenceAndOneShotMembership() {
        #expect(MacBuddyState.sleepSequence == [
            .yawning, .dozing, .collapsing, .sleeping, .waking,
        ])
        #expect(MacBuddyState.oneShot == [
            .attention, .error, .sweeping, .notification, .carrying,
        ])
    }
}
