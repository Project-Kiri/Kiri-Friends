// MacBuddyStateStore.swift
// Mac Buddy state machine. Ports the core state-resolution logic from
// .workspace/reference/clawd-on-desk/src/state.js into Swift's actor
// model.
//
// Responsibilities owned by Phase 1:
//   - Track active sessions keyed by (agent, sessionId).
//   - Resolve the display state by Clawd-on-Desk priority.
//   - Auto-return one-shot states (attention / error / notification /
//     sweeping / carrying) to the prior dominant session state.
//   - Lock the display state at `.notification` while a permission bubble
//     is active.
//   - Cap session count at MAX_SESSIONS (upstream uses 20).
//   - Emit `MacBuddyDisplaySnapshot` events through an `AsyncStream`.
//
// Sleep sequence timing (yawning → dozing → collapsing) is tied to
// mouse-activity polling and ships with Phase 2/3.

import Foundation

public actor MacBuddyStateStore {
    public static let maxSessions = 20

    /// Minimum display window for one-shot states, mirroring
    /// `theme.timings.minDisplay` from the Clawd theme but defaulted here
    /// so the state machine has correct behavior without a theme loaded.
    public struct Timings: Sendable, Hashable {
        public var attention: Duration
        public var error: Duration
        public var sweeping: Duration
        public var notification: Duration
        public var carrying: Duration

        public init(
            attention: Duration = .milliseconds(4_000),
            error: Duration = .milliseconds(5_000),
            sweeping: Duration = .milliseconds(5_500),
            notification: Duration = .milliseconds(5_000),
            carrying: Duration = .milliseconds(3_000)
        ) {
            self.attention = attention
            self.error = error
            self.sweeping = sweeping
            self.notification = notification
            self.carrying = carrying
        }

        public func autoReturn(for state: MacBuddyState) -> Duration? {
            switch state {
            case .attention: return attention
            case .error: return error
            case .sweeping: return sweeping
            case .notification: return notification
            case .carrying: return carrying
            default: return nil
            }
        }
    }

    private var sessions: [BuddySessionKey: BuddySession] = [:]
    private var permissionLocked: Bool = false
    private let clock: any Clock<Duration>
    private let timings: Timings
    private var continuations: [UUID: AsyncStream<MacBuddyDisplaySnapshot>.Continuation] = [:]
    private var pendingAutoReturn: [BuddySessionKey: Task<Void, Never>] = [:]
    private var lastSnapshot: MacBuddyDisplaySnapshot = .sleeping

    public init<C: Clock>(
        clock: C = ContinuousClock(),
        timings: Timings = Timings()
    ) where C.Duration == Duration {
        self.clock = clock
        self.timings = timings
    }

    // MARK: - Subscription

    public func subscribe() -> AsyncStream<MacBuddyDisplaySnapshot> {
        AsyncStream { continuation in
            let id = UUID()
            continuations[id] = continuation
            continuation.yield(lastSnapshot)
            continuation.onTermination = { [weak self] _ in
                guard let self else { return }
                Task { await self.removeContinuation(id: id) }
            }
        }
    }

    private func removeContinuation(id: UUID) {
        continuations.removeValue(forKey: id)
    }

    // MARK: - Public API

    /// Returns the current display snapshot synchronously. UI code should
    /// prefer `subscribe()` to observe changes; this is the test seam.
    public func currentSnapshot() -> MacBuddyDisplaySnapshot {
        lastSnapshot
    }

    /// Applies a normalized state event. Returns the resulting snapshot.
    @discardableResult
    public func apply(event: MacBuddyStateEvent) -> MacBuddyDisplaySnapshot {
        let key = BuddySessionKey(agent: event.agent, sessionId: event.sessionId)
        cancelAutoReturn(for: key)

        var session = sessions[key] ?? BuddySession(
            key: key,
            state: event.resolvedState,
            lastEventAt: event.receivedAt,
            lastEventName: event.event
        )
        session.state = event.resolvedState
        session.cwd = event.cwd ?? session.cwd
        session.lastEventAt = event.receivedAt
        session.lastEventName = event.event

        // The Clawd state machine drops the session record entirely when a
        // SessionEnd-like event resolves to `.sleeping`; this keeps the
        // dominant-session resolver clean.
        if event.resolvedState == .sleeping {
            sessions.removeValue(forKey: key)
        } else {
            sessions[key] = session
            evictOldestIfNeeded()
        }

        if MacBuddyState.oneShot.contains(event.resolvedState) {
            scheduleAutoReturn(for: key, state: event.resolvedState, at: event.receivedAt)
        }

        return recomputeSnapshot(at: event.receivedAt)
    }

    /// Forcibly clears a session, mirroring `cleanStaleSessions` in
    /// upstream. Used when a CLI process exits and cleanup arrives via a
    /// non-event channel.
    @discardableResult
    public func clearSession(_ key: BuddySessionKey, now: Date = Date()) -> MacBuddyDisplaySnapshot {
        cancelAutoReturn(for: key)
        sessions.removeValue(forKey: key)
        return recomputeSnapshot(at: now)
    }

    /// Drops every session. Useful for testing and DND tear-down.
    @discardableResult
    public func reset(now: Date = Date()) -> MacBuddyDisplaySnapshot {
        for task in pendingAutoReturn.values { task.cancel() }
        pendingAutoReturn.removeAll()
        sessions.removeAll()
        permissionLocked = false
        return recomputeSnapshot(at: now)
    }

    /// Sets the permission lock flag; while locked the display resolves to
    /// `.notification` regardless of any session-driven state. Mirrors
    /// `kimiPermissionHolds.size > 0` in upstream `state.js`.
    @discardableResult
    public func setPermissionLocked(_ locked: Bool, now: Date = Date()) -> MacBuddyDisplaySnapshot {
        permissionLocked = locked
        return recomputeSnapshot(at: now)
    }

    // MARK: - Auto-return scheduling

    private func scheduleAutoReturn(
        for key: BuddySessionKey,
        state: MacBuddyState,
        at now: Date
    ) {
        guard let delay = timings.autoReturn(for: state) else { return }
        let task = Task { [weak self, clock] in
            try? await clock.sleep(for: delay)
            guard !Task.isCancelled else { return }
            await self?.autoReturnExpired(for: key, state: state, scheduledFrom: now)
        }
        pendingAutoReturn[key] = task
    }

    private func cancelAutoReturn(for key: BuddySessionKey) {
        pendingAutoReturn.removeValue(forKey: key)?.cancel()
    }

    private func autoReturnExpired(
        for key: BuddySessionKey,
        state: MacBuddyState,
        scheduledFrom timestamp: Date
    ) {
        guard var session = sessions[key], session.state == state else { return }
        // Auto-return falls back to idle when no peer hint exists. The
        // theme-aware "return to last visual" path lands in Phase 4 when
        // theme history is available.
        session.state = .idle
        session.lastEventAt = Date()
        session.lastEventName = "auto-return"
        sessions[key] = session
        pendingAutoReturn.removeValue(forKey: key)
        _ = recomputeSnapshot(at: Date())
    }

    // MARK: - Display state resolution

    private func recomputeSnapshot(at now: Date) -> MacBuddyDisplaySnapshot {
        let resolvedState = resolveDisplayState()
        let snapshot = MacBuddyDisplaySnapshot(
            displayState: resolvedState,
            sessions: sessions.values.sorted(by: sessionOrdering),
            permissionLocked: permissionLocked,
            updatedAt: now
        )
        lastSnapshot = snapshot
        broadcast(snapshot: snapshot)
        return snapshot
    }

    private func resolveDisplayState() -> MacBuddyState {
        if permissionLocked { return .notification }

        let nonHeadlessSessions = sessions.values.filter { !$0.headless }
        guard !nonHeadlessSessions.isEmpty else {
            return sessions.isEmpty ? .sleeping : .idle
        }

        return nonHeadlessSessions.reduce(MacBuddyState.idle) { acc, session in
            acc.priority >= session.state.priority ? acc : session.state
        }
    }

    private func evictOldestIfNeeded() {
        guard sessions.count > Self.maxSessions else { return }
        let oldest = sessions.values.min { lhs, rhs in
            lhs.lastEventAt < rhs.lastEventAt
        }
        guard let oldest else { return }
        sessions.removeValue(forKey: oldest.key)
        cancelAutoReturn(for: oldest.key)
    }

    private func broadcast(snapshot: MacBuddyDisplaySnapshot) {
        for continuation in continuations.values {
            continuation.yield(snapshot)
        }
    }

    private func sessionOrdering(lhs: BuddySession, rhs: BuddySession) -> Bool {
        if lhs.state.priority != rhs.state.priority {
            return lhs.state.priority > rhs.state.priority
        }
        return lhs.lastEventAt > rhs.lastEventAt
    }
}
