// BridgeAppModel.swift
// Top-level Observable that owns the bridge service for the SwiftUI app.
// Tracks the bridge's bound port and the current display snapshot so the
// Phase 0 placeholder view can surface the bridge's health to the user.

import Foundation
import KiriFriendsMacBuddyKit
import Observation

@Observable
@MainActor
public final class BridgeAppModel {
    public enum BridgeStatus: Equatable, Sendable {
        case stopped
        case starting
        case running(port: UInt16)
        case failed(String)
    }

    public var status: BridgeStatus = .stopped
    public var snapshot: MacBuddyDisplaySnapshot = .sleeping

    public let bridge: BridgeService
    private var subscriptionTask: Task<Void, Never>?

    public init(bridge: BridgeService? = nil) {
        self.bridge = bridge ?? BridgeService()
    }

    public func start() async {
        guard case .stopped = status else { return }
        status = .starting
        do {
            try await bridge.start()
            if let port = await bridge.boundPort() {
                status = .running(port: port)
            } else {
                status = .failed("bridge started but no port reported")
            }
            await observeSnapshots()
        } catch {
            status = .failed("\(error)")
        }
    }

    public func stop() async {
        subscriptionTask?.cancel()
        subscriptionTask = nil
        await bridge.stop()
        status = .stopped
    }

    private func observeSnapshots() async {
        subscriptionTask?.cancel()
        let stream = await bridge.store.subscribe()
        subscriptionTask = Task { [weak self] in
            for await snapshot in stream {
                await MainActor.run {
                    self?.snapshot = snapshot
                }
            }
        }
    }
}
