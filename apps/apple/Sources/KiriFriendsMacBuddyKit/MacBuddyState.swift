// MacBuddyState.swift
// Animation state vocabulary for the Mac desktop buddy. Aligned with
// Clawd-on-Desk's STATE_PRIORITY table (.workspace/reference/clawd-on-desk/
// src/state-priority.js) so the upstream state machine ports without
// renaming. The cross-device `BuddyPersonaState` defined in
// KiriFriendsCore is a lossy projection consumed by the iPhone companion
// and Watch surfaces.

import Foundation
import KiriFriendsCore

public enum MacBuddyState: String, Codable, Hashable, Sendable, CaseIterable {
    /// Deep sleep; lowest priority, only displayed when no session is active.
    case sleeping
    /// Sleep sequence intro frame.
    case yawning
    /// Sleep sequence middle frame.
    case dozing
    /// Sleep sequence collapse frame.
    case collapsing
    /// Sleep sequence exit (wake-up) frame.
    case waking
    /// Active but no work in progress.
    case idle
    /// Model is reading or planning.
    case thinking
    /// Tool execution is active; visual tier resolved by session count.
    case working
    /// One subagent active.
    case juggling
    /// Long-lived tool runs (worktrees, compaction work outputs, etc).
    case carrying
    /// Task completion / happy display; auto-returns to idle.
    case attention
    /// Background sweep / compact in progress.
    case sweeping
    /// Approval bubble or other actionable notification pending.
    case notification
    /// Tool failure or session error.
    case error
}

public extension MacBuddyState {
    /// Priority taken from Clawd-on-Desk's `STATE_PRIORITY`. Higher wins
    /// when multiple sessions compete for the displayed state.
    var priority: Int {
        switch self {
        case .sleeping, .yawning, .dozing, .collapsing, .waking:
            return 0
        case .idle:
            return 1
        case .thinking:
            return 2
        case .working:
            return 3
        case .juggling, .carrying:
            return 4
        case .attention:
            return 5
        case .sweeping:
            return 6
        case .notification:
            return 7
        case .error:
            return 8
        }
    }

    /// Members of the sleep sequence (yawn → doze → collapse → sleep → wake).
    static let sleepSequence: Set<MacBuddyState> = [
        .yawning, .dozing, .collapsing, .sleeping, .waking,
    ]

    /// States that auto-return to the prior state after their display window.
    static let oneShot: Set<MacBuddyState> = [
        .attention, .error, .sweeping, .notification, .carrying,
    ]

    /// Maps the local animation state to the persona projection shared with
    /// the watch / iPhone surfaces.
    var personaProjection: BuddyPersonaState {
        switch self {
        case .sleeping, .yawning, .dozing, .collapsing, .waking:
            return .sleep
        case .idle:
            return .idle
        case .thinking, .working, .juggling, .carrying, .sweeping:
            return .running
        case .attention:
            return .celebrate
        case .notification:
            return .attention
        case .error:
            return .failed
        }
    }
}
