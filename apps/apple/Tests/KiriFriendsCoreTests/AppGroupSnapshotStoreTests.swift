import Foundation
import Testing
@testable import KiriFriendsCore

@Suite("AppGroupSnapshotStore")
struct AppGroupSnapshotStoreTests {
    @Test("Saving then loading round-trips the complication snapshot")
    func roundTripsSnapshot() throws {
        let suiteName = "kiri-appgroup-\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defer { defaults.removePersistentDomain(forName: suiteName) }

        let store = AppGroupSnapshotStore(defaults: defaults)
        let snapshot = ComplicationSnapshot(
            updatedAt: Date(timeIntervalSince1970: 1_779_020_400),
            shortStatus: "Running +2",
            detail: "claude-code +2",
            symbolName: "play.fill",
            sensitivity: .none
        )
        store.saveComplicationSnapshot(snapshot)
        let loaded = store.loadComplicationSnapshot()
        #expect(loaded == snapshot)
    }

    @Test("Loading without a prior save returns nil")
    func emptyDefaultsLoadNil() {
        let suiteName = "kiri-appgroup-empty-\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defer { defaults.removePersistentDomain(forName: suiteName) }

        let store = AppGroupSnapshotStore(defaults: defaults)
        #expect(store.loadComplicationSnapshot() == nil)
    }
}
