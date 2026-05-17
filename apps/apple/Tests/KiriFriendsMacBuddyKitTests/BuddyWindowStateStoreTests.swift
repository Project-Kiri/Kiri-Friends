// BuddyWindowStateStoreTests.swift
// Verifies the buddy window position persistence layer that backs Phase
// 3 position memory.

import Foundation
import KiriFriendsMacBuddyKit
import Testing

@Suite("BuddyWindowStateStore")
struct BuddyWindowStateStoreTests {
    @Test("Save then load round-trips the window state")
    func roundTripsState() async throws {
        let tempHome = makeTempHome()
        defer { try? FileManager.default.removeItem(at: tempHome) }

        let store = BuddyWindowStateStore(homeDirectory: tempHome)
        let state = BuddyWindowState(originX: 120, originY: 240, displayIdentifier: 1)
        await store.save(state)
        let loaded = await store.load()

        #expect(loaded?.originX == 120)
        #expect(loaded?.originY == 240)
        #expect(loaded?.displayIdentifier == 1)
    }

    @Test("Load returns nil when no state has been written yet")
    func emptyDirectoryReturnsNil() async {
        let tempHome = makeTempHome()
        defer { try? FileManager.default.removeItem(at: tempHome) }
        let store = BuddyWindowStateStore(homeDirectory: tempHome)
        let loaded = await store.load()
        #expect(loaded == nil)
    }

    private func makeTempHome() -> URL {
        let url = FileManager.default.temporaryDirectory.appending(path: UUID().uuidString, directoryHint: .isDirectory)
        try? FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        return url
    }
}
