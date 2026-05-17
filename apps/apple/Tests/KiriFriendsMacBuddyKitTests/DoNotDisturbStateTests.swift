// DoNotDisturbStateTests.swift
// Verifies the DND flag and its broadcast semantics.

import Foundation
import KiriFriendsMacBuddyKit
import Testing

@Suite("DoNotDisturbState")
struct DoNotDisturbStateTests {
    @Test("Toggle flips the value")
    func toggleFlipsValue() async {
        let dnd = DoNotDisturbState()
        #expect(await dnd.isEnabled == false)
        let nextValue = await dnd.toggle()
        #expect(nextValue == true)
        #expect(await dnd.isEnabled == true)
    }

    @Test("Updates stream yields the latest value")
    func updatesStreamYields() async throws {
        let dnd = DoNotDisturbState()
        let stream = await dnd.updates()
        var iterator = stream.makeAsyncIterator()
        let initial = await iterator.next()
        #expect(initial == false)
        await dnd.set(enabled: true)
        let next = await iterator.next()
        #expect(next == true)
    }
}
