import Foundation
import KiriFriendsCore
import Observation

#if canImport(WatchConnectivity)
import WatchConnectivity

@Observable
public final class WatchSessionStore: NSObject {
    public private(set) var snapshot: StateSnapshot
    public private(set) var buddySettings: BuddySettings?
    public private(set) var lastErrorDescription: String?

    private let session: WCSession
    private let cache: WatchStateCache

    public init(
        session: WCSession = .default,
        cache: WatchStateCache = WatchStateCache()
    ) {
        self.session = session
        self.cache = cache
        self.snapshot = cache.loadRuntimeSnapshot() ?? .empty
        super.init()
    }

    public func activate() {
        guard WCSession.isSupported() else { return }
        session.delegate = self
        session.activate()
    }

    public func sendAction(_ action: WatchAction) {
        applyOptimisticDecision(for: action)

        do {
            let payload = try WatchConnectivityPayload.dictionary(from: action)
            session.sendMessage(payload, replyHandler: nil) { [weak self] error in
                self?.lastErrorDescription = error.localizedDescription
            }
        } catch {
            lastErrorDescription = error.localizedDescription
        }
    }

    public func sendHealthSummary(_ summary: HealthSignalSummary) {
        guard session.isReachable else { return }
        guard let payload = try? WatchConnectivityPayload.dictionary(from: summary) else { return }
        session.sendMessage(payload, replyHandler: nil)
    }

    /// Public seam for `WCSessionDelegate.session(_:didReceiveApplicationContext:)`
    /// so tests can drive the dispatcher without a real session.
    public func ingest(applicationContext: [String: Any]) {
        for entry in WatchConnectivityEnvelope.unpack(applicationContext) {
            handle(kind: entry.kind, payload: entry.payload)
        }
    }

    private func handle(kind: WatchPayloadKind, payload: [String: Any]) {
        switch kind {
        case .stateSnapshot:
            if let snapshot = try? WatchConnectivityPayload.decode(StateSnapshot.self, from: payload) {
                apply(snapshot)
            }
        case .buddySettings:
            if let settings = try? WatchConnectivityPayload.decode(BuddySettings.self, from: payload) {
                buddySettings = settings
            }
        case .watchAction, .healthSignalSummary:
            // Phone-bound payloads should not appear on the watch; ignore.
            break
        }
    }

    private func apply(_ snapshot: StateSnapshot) {
        if snapshot.schemaVersion != self.snapshot.schemaVersion {
            // Schema bump observed; the watch keeps decoding optimistically
            // but records the mismatch so future telemetry hooks can flag
            // diverging contracts.
            lastErrorDescription = "snapshot schemaVersion=\(snapshot.schemaVersion) does not match \(self.snapshot.schemaVersion)"
        }
        self.snapshot = snapshot
        cache.save(snapshot)
    }

    func applyOptimisticDecision(for action: WatchAction) {
        guard action.action == .approvalAllow || action.action == .approvalDeny else { return }

        let targetSessionId = action.sessionId ?? snapshot.approval?.sessionId ?? snapshot.session?.id
        let nextState: SessionState = action.action == .approvalAllow ? .running : .failed

        var next = snapshot
        next.updatedAt = action.createdAt
        next.approval = nil

        if let targetSessionId, next.session?.id == targetSessionId {
            next.session?.state = nextState
            next.session?.title = ""
            next.session?.summary = ""
            next.session?.sensitivity = .none
        }

        next.sessions = next.sessions.map { session in
            guard let targetSessionId, session.id == targetSessionId else { return session }
            var updated = session
            updated.state = nextState
            updated.title = ""
            updated.summary = ""
            updated.sensitivity = .none
            return updated
        }

        apply(next)
    }
}

extension WatchSessionStore: WCSessionDelegate {
    public func session(
        _ session: WCSession,
        activationDidCompleteWith activationState: WCSessionActivationState,
        error: Error?
    ) {
        lastErrorDescription = error?.localizedDescription
        ingest(applicationContext: session.receivedApplicationContext)
    }

    public func session(_ session: WCSession, didReceiveApplicationContext applicationContext: [String: Any]) {
        ingest(applicationContext: applicationContext)
    }

    public func session(_ session: WCSession, didReceiveUserInfo userInfo: [String: Any]) {
        ingest(applicationContext: userInfo)
    }

    #if os(iOS)
    public func sessionDidBecomeInactive(_ session: WCSession) {}

    public func sessionDidDeactivate(_ session: WCSession) {
        session.activate()
    }
    #endif
}
#else
public final class WatchSessionStore {
    public private(set) var snapshot: StateSnapshot
    public private(set) var buddySettings: BuddySettings?
    public private(set) var lastErrorDescription: String?

    private let cache: WatchStateCache

    public init(cache: WatchStateCache = WatchStateCache()) {
        self.cache = cache
        self.snapshot = cache.loadRuntimeSnapshot() ?? .empty
    }

    public func activate() {}
    public func sendAction(_ action: WatchAction) {
        applyOptimisticDecision(for: action)
    }
    public func sendHealthSummary(_ summary: HealthSignalSummary) {}

    public func ingest(applicationContext: [String: Any]) {
        for entry in WatchConnectivityEnvelope.unpack(applicationContext) {
            switch entry.kind {
            case .stateSnapshot:
                if let snapshot = try? WatchConnectivityPayload.decode(StateSnapshot.self, from: entry.payload) {
                    self.snapshot = snapshot
                    cache.save(snapshot)
                }
            case .buddySettings:
                if let settings = try? WatchConnectivityPayload.decode(BuddySettings.self, from: entry.payload) {
                    buddySettings = settings
                }
            case .watchAction, .healthSignalSummary:
                break
            }
        }
    }

    func applyOptimisticDecision(for action: WatchAction) {
        guard action.action == .approvalAllow || action.action == .approvalDeny else { return }

        let targetSessionId = action.sessionId ?? snapshot.approval?.sessionId ?? snapshot.session?.id
        let nextState: SessionState = action.action == .approvalAllow ? .running : .failed

        var next = snapshot
        next.updatedAt = action.createdAt
        next.approval = nil

        if let targetSessionId, next.session?.id == targetSessionId {
            next.session?.state = nextState
            next.session?.title = ""
            next.session?.summary = ""
            next.session?.sensitivity = .none
        }

        next.sessions = next.sessions.map { session in
            guard let targetSessionId, session.id == targetSessionId else { return session }
            var updated = session
            updated.state = nextState
            updated.title = ""
            updated.summary = ""
            updated.sensitivity = .none
            return updated
        }

        snapshot = next
        cache.save(next)
    }
}
#endif

public struct WatchStateCache {
    private let defaults: UserDefaults
    private let key: String

    public init(defaults: UserDefaults = .standard, key: String = "KiriFriends.latestSnapshot") {
        self.defaults = defaults
        self.key = key
    }

    public func loadSnapshot() -> StateSnapshot? {
        guard let data = defaults.data(forKey: key) else { return nil }
        return try? KiriJSON.decoder.decode(StateSnapshot.self, from: data)
    }

    public func loadRuntimeSnapshot() -> StateSnapshot? {
        guard let snapshot = loadSnapshot() else { return nil }
        if snapshot == .placeholder {
            defaults.removeObject(forKey: key)
            return nil
        }
        return snapshot
    }

    public func save(_ snapshot: StateSnapshot) {
        guard let data = try? KiriJSON.encoder.encode(snapshot) else { return }
        defaults.set(data, forKey: key)
    }
}
