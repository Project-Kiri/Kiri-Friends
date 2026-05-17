import Foundation
import KiriFriendsCore

public struct BridgeStateStore: Sendable {
    public private(set) var latestSnapshot: StateSnapshot

    public init(latestSnapshot: StateSnapshot = .placeholder) {
        self.latestSnapshot = latestSnapshot
    }

    public mutating func update(_ snapshot: StateSnapshot) {
        latestSnapshot = snapshot
    }
}
