// BridgeRuntime.swift
// Top-level coordinator for the iPhone companion. Pulls events from the
// relay, folds them into `BridgeStateStore`, and fans the resulting
// `StateSnapshot` out to:
//
//   - `PhoneWatchConnectivityController.syncSnapshot` (Watch app)
//   - `AppGroupSnapshotStore.saveComplicationSnapshot` (Widget)
//
// Watch-originated `WatchAction`s flow back the other way through
// `RelayDownlinkClient.sendRequest`.

import Foundation
import KiriFriendsCore
#if canImport(WidgetKit)
import WidgetKit
#endif

@MainActor
public final class BridgeRuntime {
    public let store: BridgeStateStore

    private let client: any RelayDownlinkClient
    private let watchController: PhoneWatchConnectivityController?
    private let appGroupStore: AppGroupSnapshotStore?
    private let userId: String
    private let macDeviceId: String?
    private let approvalLifetime: TimeInterval

    private var streamTask: Task<Void, Never>?
    private var watchActionHandler: ((WatchAction) -> Void)?

    public init(
        store: BridgeStateStore = BridgeStateStore(latestSnapshot: BridgeRuntime.emptySnapshot()),
        client: any RelayDownlinkClient,
        watchController: PhoneWatchConnectivityController? = nil,
        appGroupStore: AppGroupSnapshotStore? = nil,
        userId: String,
        macDeviceId: String? = nil,
        approvalLifetime: TimeInterval = 100
    ) {
        self.store = store
        self.client = client
        self.watchController = watchController
        self.appGroupStore = appGroupStore
        self.userId = userId
        self.macDeviceId = macDeviceId
        self.approvalLifetime = approvalLifetime
    }

    public static func emptySnapshot() -> StateSnapshot {
        StateSnapshot(
            updatedAt: .distantPast,
            activeTool: .unknown,
            connectionState: .unknown,
            session: nil
        )
    }

    public func start() async {
        watchController?.activate()
        watchController?.onWatchAction = { [weak self] action in
            guard let self else { return }
            Task { @MainActor in
                self.handle(action: action)
            }
        }
        streamTask?.cancel()
        let cursor = store.lastEventId
        let stream = client.streamEvents(since: cursor)
        streamTask = Task { @MainActor [weak self] in
            for await event in stream {
                guard let self else { break }
                let changed = self.store.apply(event: event)
                if changed {
                    self.publishSnapshot()
                }
            }
        }
    }

    public func stop() {
        streamTask?.cancel()
        streamTask = nil
    }

    public func publishSnapshot() {
        let snapshot = store.latestSnapshot
        try? watchController?.syncSnapshot(snapshot)
        if let appGroupStore {
            let complication = BuddyPresentationReducer.complicationSnapshot(for: snapshot)
            appGroupStore.saveComplicationSnapshot(complication)
            reloadWidgetTimelines()
        }
    }

    public func publishBuddySettings(_ settings: BuddySettings) throws {
        try watchController?.syncBuddySettings(settings)
    }

    private func handle(action: WatchAction) {
        guard let macDeviceId else { return }
        let mapped = mapAction(action, macDeviceId: macDeviceId)
        Task { [client] in
            try? await client.sendRequest(mapped)
        }
        watchActionHandler?(action)
    }

    private func mapAction(_ action: WatchAction, macDeviceId: String) -> RelayRequestEnvelope {
        var payload: [String: RelayValue] = [:]
        payload["action"] = .string(action.action.rawValue)
        if let sessionId = action.sessionId {
            payload["sessionId"] = .string(sessionId)
        }
        if let approvalId = action.approvalId {
            payload["approvalId"] = .string(approvalId)
        }
        return RelayRequestEnvelope(
            targetDeviceId: macDeviceId,
            sessionId: action.sessionId,
            kind: action.action.rawValue,
            expiresAt: action.createdAt.addingTimeInterval(approvalLifetime),
            idempotencyKey: "\(action.action.rawValue)-\(action.sessionId ?? "no-session")-\(Int(action.createdAt.timeIntervalSince1970 * 1000))",
            payload: payload
        )
    }

    public func setWatchActionHandler(_ handler: ((WatchAction) -> Void)?) {
        watchActionHandler = handler
    }

    /// Test seam for exercising the watch-action path without a live
    /// WatchConnectivity session.
    public func handleForTesting(action: WatchAction) {
        handle(action: action)
    }

    private func reloadWidgetTimelines() {
        #if canImport(WidgetKit) && !os(macOS)
        WidgetCenter.shared.reloadAllTimelines()
        #endif
    }
}
