// DoNotDisturbState.swift
// Centralised DND flag. While DND is enabled the buddy state store
// rejects mutation events and the permission service auto-declines
// pending requests so the host CLIs fall back to their native flows
// without the user having to act.

import Foundation

public actor DoNotDisturbState {
    public private(set) var isEnabled: Bool = false
    private var listeners: [UUID: AsyncStream<Bool>.Continuation] = [:]

    public init(initial: Bool = false) {
        self.isEnabled = initial
    }

    public func set(enabled: Bool) {
        guard enabled != isEnabled else { return }
        isEnabled = enabled
        broadcast()
    }

    public func toggle() -> Bool {
        set(enabled: !isEnabled)
        return isEnabled
    }

    public func updates() -> AsyncStream<Bool> {
        AsyncStream { continuation in
            let id = UUID()
            listeners[id] = continuation
            continuation.yield(isEnabled)
            continuation.onTermination = { [weak self] _ in
                guard let self else { return }
                Task { await self.removeListener(id: id) }
            }
        }
    }

    private func removeListener(id: UUID) {
        listeners.removeValue(forKey: id)
    }

    private func broadcast() {
        for continuation in listeners.values {
            continuation.yield(isEnabled)
        }
    }
}
