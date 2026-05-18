import Foundation
import KiriFriendsCore

public enum BuddyAnimationResolver {
    public static func request(
        for snapshot: StateSnapshot,
        presentation: BuddyPresentation,
        theme: BundledBuddyTheme,
        isLuminanceReduced: Bool = false
    ) -> BuddyAnimationRequest? {
        guard let spec = theme.animationSpec else { return nil }
        let visualState = desktopVisualState(
            for: snapshot,
            presentation: presentation,
            isLuminanceReduced: isLuminanceReduced
        )
        guard let sourceFile = sourceFile(
            for: visualState,
            snapshot: snapshot,
            spec: spec
        ) else {
            return nil
        }

        return BuddyAnimationRequest(
            themeNamespace: theme.namespace,
            visualState: visualState,
            sourceFile: sourceFile,
            layout: spec.layout
        )
    }

    public static func desktopVisualState(
        for snapshot: StateSnapshot,
        presentation: BuddyPresentation,
        isLuminanceReduced: Bool = false
    ) -> BuddyDesktopVisualState {
        if isLuminanceReduced { return .sleeping }
        if snapshot.approval != nil { return .notification }

        switch snapshot.session?.state {
        case .waitingForApproval:
            return .notification
        case .running:
            return .working
        case .waitingForInput:
            return .attention
        case .completed:
            return .attention
        case .failed:
            return .error
        case .idle, .unknown, .none:
            return presentation.state == .sleep ? .sleeping : .idle
        }
    }

    private static func sourceFile(
        for visualState: BuddyDesktopVisualState,
        snapshot: StateSnapshot,
        spec: BuddyAnimationSpec
    ) -> String? {
        let activeSessions = activeSessionCount(in: snapshot)
        switch visualState {
        case .working:
            return spec.tieredWorkingFile(activeSessions: activeSessions)
        case .juggling:
            return spec.tieredJugglingFile(activeSessions: activeSessions)
        default:
            return spec.primaryFile(for: visualState)
        }
    }

    private static func activeSessionCount(in snapshot: StateSnapshot) -> Int {
        let sessions = snapshotSessions(from: snapshot)
        let count = sessions.filter { session in
            switch session.state {
            case .running:
                return true
            case .idle, .waitingForInput, .waitingForApproval, .failed, .completed, .unknown:
                return false
            }
        }.count
        return max(count, snapshot.session?.state == .running ? 1 : 0)
    }

    private static func snapshotSessions(from snapshot: StateSnapshot) -> [CLISessionSummary] {
        if !snapshot.sessions.isEmpty { return snapshot.sessions }
        if let session = snapshot.session { return [session] }
        return []
    }
}
