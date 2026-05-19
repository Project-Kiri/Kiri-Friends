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
#if canImport(Speech)
import Speech
#if os(iOS)
import AVFoundation
#endif
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
    private var sharesHealthContext: Bool

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
        self.sharesHealthContext = false
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
        watchController?.onReceivedHealthSummary = { [weak self] summary in
            guard let self else { return }
            Task { @MainActor in
                self.handle(healthSummary: summary)
            }
        }
        streamTask?.cancel()
        store.updateConnectionState(client.startupConnectionState)
        publishSnapshot()
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

    public func setSharesHealthContext(_ enabled: Bool) {
        sharesHealthContext = enabled
        if !enabled {
            store.updateHealthSummary(nil)
            publishSnapshot()
        }
    }

    private func handle(action: WatchAction) {
        if action.action == .voiceInputRequest {
            #if canImport(Speech) && os(iOS)
            Task {
                await performVoiceRecognition(requestAction: action)
            }
            #endif
            return
        }

        guard let macDeviceId else { return }
        let mapped = mapAction(action, macDeviceId: macDeviceId)
        Task { [client] in
            try? await client.sendRequest(mapped)
        }
        watchActionHandler?(action)
    }

    #if canImport(Speech) && os(iOS)
    private func performVoiceRecognition(requestAction: WatchAction) async {
        let authStatus = await withCheckedContinuation { continuation in
            SFSpeechRecognizer.requestAuthorization { status in
                continuation.resume(returning: status)
            }
        }
        guard authStatus == .authorized else { return }

        let audioSession = AVAudioSession.sharedInstance()
        try? audioSession.setCategory(.record, mode: .measurement, options: .duckOthers)
        try? audioSession.setActive(true, options: .notifyOthersOnDeactivation)

        let recognizer = SFSpeechRecognizer(locale: Locale.current)
        let request = SFSpeechAudioBufferRecognitionRequest()
        request.shouldReportPartialResults = true

        let audioEngine = AVAudioEngine()
        let inputNode = audioEngine.inputNode
        let recordingFormat = inputNode.outputFormat(forBus: 0)
        inputNode.installTap(onBus: 0, bufferSize: 1024, format: recordingFormat) { buffer, _ in
            request.append(buffer)
        }

        audioEngine.prepare()
        try? audioEngine.start()

        let text = await withCheckedContinuation { (continuation: CheckedContinuation<String, Never>) in
            var hasResumed = false
            func resume(with value: String) {
                guard !hasResumed else { return }
                hasResumed = true
                continuation.resume(returning: value)
            }

            let task = recognizer?.recognitionTask(with: request) { result, error in
                if let result, result.isFinal {
                    resume(with: result.bestTranscription.formattedString)
                } else if error != nil {
                    resume(with: "")
                }
            }

            Task {
                try? await Task.sleep(for: .seconds(30))
                task?.cancel()
                resume(with: "")
            }
        }

        audioEngine.stop()
        inputNode.removeTap(onBus: 0)
        try? audioSession.setActive(false)

        guard !text.isEmpty else { return }

        let sendAction = WatchAction(
            action: .promptSendQuick,
            sessionId: requestAction.sessionId,
            approvalId: requestAction.approvalId,
            text: text,
            createdAt: .now
        )
        handle(action: sendAction)

        connectivity.sendVoiceTranscription(text)
    }
    #endif

    private func handle(healthSummary: HealthSignalSummary) {
        guard sharesHealthContext else { return }
        store.updateHealthSummary(healthSummary)
        publishSnapshot()
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
        if let text = action.text {
            payload["text"] = .string(text)
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

    public func handleHealthSummaryForTesting(_ summary: HealthSignalSummary) {
        handle(healthSummary: summary)
    }

    private func reloadWidgetTimelines() {
        #if canImport(WidgetKit) && !os(macOS)
        WidgetCenter.shared.reloadAllTimelines()
        #endif
    }
}
