import Foundation
import KiriFriendsCore

#if canImport(WatchConnectivity)
import WatchConnectivity

public final class PhoneWatchConnectivityController: NSObject {
    public var onWatchAction: ((WatchAction) -> Void)?
    public var onReceivedHealthSummary: ((HealthSignalSummary) -> Void)?

    private let session: WCSession
    // Local copy of the application context envelope. Mutated by every
    // sync* call before being flushed to `WCSession.updateApplicationContext`
    // so distinct kinds (state snapshot vs buddy settings) coexist
    // instead of overwriting each other.
    private var pendingContext: [String: Any] = [:]
    private let contextLock = NSLock()

    public init(session: WCSession = .default) {
        self.session = session
        super.init()
    }

    public func activate() {
        guard WCSession.isSupported() else { return }
        session.delegate = self
        session.activate()
    }

    public func syncSnapshot(_ snapshot: StateSnapshot) throws {
        try mergeAndFlush(kind: .stateSnapshot, value: snapshot)
    }

    public func syncBuddySettings(_ settings: BuddySettings) throws {
        try mergeAndFlush(kind: .buddySettings, value: settings)
    }

    @discardableResult
    public func transferBuddyAsset(fileURL: URL, manifest: BuddyAssetManifest) throws -> WCSessionFileTransfer {
        let metadata = try WatchConnectivityPayload.dictionary(from: manifest)
        return session.transferFile(fileURL, metadata: metadata)
    }

    private func mergeAndFlush<T: Encodable>(kind: WatchPayloadKind, value: T) throws {
        let next = try contextLock.withLock { () -> [String: Any] in
            let merged = try WatchConnectivityEnvelope.merge(
                kind: kind,
                value: value,
                into: pendingContext
            )
            pendingContext = merged
            return merged
        }
        guard session.activationState == .activated else { return }
        try session.updateApplicationContext(next)
    }

    private func flushPendingContextIfActivated() {
        guard session.activationState == .activated else { return }
        let context = contextLock.withLock { pendingContext }
        guard !context.isEmpty else { return }
        try? session.updateApplicationContext(context)
    }
}

private extension NSLock {
    func withLock<T>(_ body: () throws -> T) rethrows -> T {
        lock()
        defer { unlock() }
        return try body()
    }
}

extension PhoneWatchConnectivityController: WCSessionDelegate {
    public func session(
        _ session: WCSession,
        activationDidCompleteWith activationState: WCSessionActivationState,
        error: Error?
    ) {
        flushPendingContextIfActivated()
    }

    #if os(iOS)
    public func sessionWatchStateDidChange(_ session: WCSession) {
        flushPendingContextIfActivated()
    }

    public func sessionReachabilityDidChange(_ session: WCSession) {
        flushPendingContextIfActivated()
    }

    public func sessionDidBecomeInactive(_ session: WCSession) {}

    public func sessionDidDeactivate(_ session: WCSession) {
        session.activate()
    }
    #endif

    public func session(_ session: WCSession, didReceiveMessage message: [String: Any]) {
        handle(message)
    }

    public func session(
        _ session: WCSession,
        didReceiveMessage message: [String: Any],
        replyHandler: @escaping ([String: Any]) -> Void
    ) {
        handle(message)
        replyHandler(["status": "received"])
    }

    private func handle(_ message: [String: Any]) {
        if let kind = message["kind"] as? String, kind == "watch.action",
           let action = try? WatchConnectivityPayload.decode(WatchAction.self, from: message) {
            onWatchAction?(action)
            return
        }

        if let kind = message["kind"] as? String, kind == "health.signal.summary",
           let summary = try? WatchConnectivityPayload.decode(HealthSignalSummary.self, from: message) {
            onReceivedHealthSummary?(summary)
        }
    }
}
#else
public final class PhoneWatchConnectivityController {
    public var onWatchAction: ((WatchAction) -> Void)?
    public var onReceivedHealthSummary: ((HealthSignalSummary) -> Void)?

    public init() {}

    public func activate() {}

    public func syncSnapshot(_ snapshot: StateSnapshot) throws {}

    public func syncBuddySettings(_ settings: BuddySettings) throws {}

    public func transferBuddyAsset(fileURL: URL, manifest: BuddyAssetManifest) throws {
        throw WatchConnectivityPayloadError.notDictionary
    }
}
#endif

