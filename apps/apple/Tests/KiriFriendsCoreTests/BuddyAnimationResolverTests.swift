import Foundation
import Testing
@testable import KiriFriendsCore
@testable import KiriFriendsWatchKit

@Suite("BuddyAnimationResolver")
struct BuddyAnimationResolverTests {
    @Test("Approval maps to desktop notification animation")
    func approvalMapsToNotificationAnimation() {
        let snapshot = snapshot(
            session: session(id: "approval", state: .waitingForApproval),
            approval: ApprovalRequestSummary(
                id: "approval-id",
                sessionId: "approval",
                title: "Approve shell command?",
                summary: "make test-server",
                sensitivity: .preview,
                expiresAt: Date(timeIntervalSince1970: 100)
            )
        )
        let presentation = BuddyPresentationReducer.presentation(for: snapshot)
        let request = BuddyAnimationResolver.request(
            for: snapshot,
            presentation: presentation,
            theme: BundledBuddyThemeRegistry.clawd
        )

        #expect(request?.visualState == .notification)
        #expect(request?.sourceFile == "clawd-notification.svg")
    }

    @Test("Running sessions use tiered working animations")
    func runningSessionsUseTieredWorkingAnimations() {
        let sessions = [
            session(id: "one", state: .running),
            session(id: "two", state: .running),
            session(id: "three", state: .running),
        ]
        let snapshot = snapshot(session: sessions[0], sessions: sessions)
        let presentation = BuddyPresentationReducer.presentation(for: snapshot)
        let request = BuddyAnimationResolver.request(
            for: snapshot,
            presentation: presentation,
            theme: BundledBuddyThemeRegistry.clawd
        )

        #expect(request?.visualState == .working)
        #expect(request?.sourceFile == "clawd-working-building.svg")
    }

    @Test("Two running sessions use groove tier")
    func twoRunningSessionsUseGrooveTier() {
        let sessions = [
            session(id: "one", state: .running),
            session(id: "two", state: .running),
        ]
        let snapshot = snapshot(session: sessions[0], sessions: sessions)
        let presentation = BuddyPresentationReducer.presentation(for: snapshot)
        let request = BuddyAnimationResolver.request(
            for: snapshot,
            presentation: presentation,
            theme: BundledBuddyThemeRegistry.clawd
        )

        #expect(request?.sourceFile == "clawd-headphones-groove.svg")
    }

    @Test("Failed sessions map to desktop error animation")
    func failedSessionsMapToErrorAnimation() {
        let snapshot = snapshot(session: session(id: "failed", state: .failed))
        let presentation = BuddyPresentationReducer.presentation(for: snapshot)
        let request = BuddyAnimationResolver.request(
            for: snapshot,
            presentation: presentation,
            theme: BundledBuddyThemeRegistry.clawd
        )

        #expect(request?.visualState == .error)
        #expect(request?.sourceFile == "clawd-error.svg")
    }

    @Test("Luminance reduced uses sleeping poster")
    func luminanceReducedUsesSleepingPoster() {
        let snapshot = snapshot(
            session: session(id: "approval", state: .waitingForApproval),
            approval: ApprovalRequestSummary(
                id: "approval-id",
                sessionId: "approval",
                title: "Approve shell command?",
                summary: "make test-server",
                sensitivity: .preview,
                expiresAt: Date(timeIntervalSince1970: 100)
            )
        )
        let presentation = BuddyPresentationReducer.presentation(
            for: snapshot,
            isLuminanceReduced: true
        )
        let request = BuddyAnimationResolver.request(
            for: snapshot,
            presentation: presentation,
            theme: BundledBuddyThemeRegistry.clawd,
            isLuminanceReduced: true
        )

        #expect(request?.visualState == .sleeping)
        #expect(request?.sourceFile == "clawd-sleeping.svg")
    }

    private func snapshot(
        session: CLISessionSummary?,
        sessions: [CLISessionSummary] = [],
        approval: ApprovalRequestSummary? = nil
    ) -> StateSnapshot {
        StateSnapshot(
            updatedAt: Date(timeIntervalSince1970: 0),
            activeTool: .codex,
            connectionState: .relayConnected,
            session: session,
            sessions: sessions,
            approval: approval
        )
    }

    private func session(id: String, state: SessionState) -> CLISessionSummary {
        CLISessionSummary(
            id: id,
            state: state,
            title: "Codex",
            summary: "Working",
            sensitivity: .preview,
            tool: .codex
        )
    }
}
