import Foundation
import Testing
@testable import KiriFriendsCore
@testable import KiriFriendsWatchKit

@Suite("WatchConnectivityEnvelope")
struct WatchConnectivityEnvelopeTests {
    @Test("Merging preserves earlier kinds")
    func mergingPreservesEarlierKinds() throws {
        let settings = BuddySettings(
            activeManifestId: "com.kirifriends.bufo",
            buddyName: "Bufo",
            showsPreviewText: true,
            sharesAgentHealthContext: false
        )
        let snapshot = StateSnapshot.placeholder

        let firstContext = try WatchConnectivityEnvelope.merge(
            kind: .stateSnapshot,
            value: snapshot,
            into: [:]
        )
        let mergedContext = try WatchConnectivityEnvelope.merge(
            kind: .buddySettings,
            value: settings,
            into: firstContext
        )

        #expect(mergedContext[WatchPayloadKind.stateSnapshot.rawValue] != nil)
        #expect(mergedContext[WatchPayloadKind.buddySettings.rawValue] != nil)
    }

    @Test("Unpack dispatches to both kinds in one context")
    func unpackDispatchesBothKinds() throws {
        let settings = BuddySettings(
            activeManifestId: "com.kirifriends.bufo",
            buddyName: "Bufo",
            showsPreviewText: false,
            sharesAgentHealthContext: false
        )
        let snapshot = StateSnapshot.placeholder
        var context: [String: Any] = [:]
        context = try WatchConnectivityEnvelope.merge(kind: .stateSnapshot, value: snapshot, into: context)
        context = try WatchConnectivityEnvelope.merge(kind: .buddySettings, value: settings, into: context)

        let entries = WatchConnectivityEnvelope.unpack(context)
        let kinds = Set(entries.map(\.kind))
        #expect(kinds == [.stateSnapshot, .buddySettings])
    }

    @Test("Unpack recognises legacy single-kind contexts")
    func unpackHandlesLegacyContext() throws {
        let snapshot = StateSnapshot.placeholder
        let legacy = try WatchConnectivityPayload.dictionary(from: snapshot)
        let entries = WatchConnectivityEnvelope.unpack(legacy)
        #expect(entries.count == 1)
        #expect(entries.first?.kind == .stateSnapshot)
    }

    @Test("Merging strips unknown top-level keys")
    func mergingStripsUnknownKeys() throws {
        let snapshot = StateSnapshot.placeholder
        let polluted: [String: Any] = [
            "junk": "noise",
            WatchPayloadKind.stateSnapshot.rawValue: ["kind": "state.snapshot"],
        ]
        let next = try WatchConnectivityEnvelope.merge(
            kind: .stateSnapshot,
            value: snapshot,
            into: polluted
        )
        #expect(next["junk"] == nil)
    }
}

@Suite("WatchSessionStore dispatch")
struct WatchSessionStoreDispatchTests {
    @Test("Empty watch cache starts from neutral runtime state")
    func emptyCacheStartsNeutral() {
        let suite = "kiri-watch-dispatch-empty-\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suite)!
        defer { defaults.removePersistentDomain(forName: suite) }

        let cache = WatchStateCache(defaults: defaults, key: "snapshot")
        let store = WatchSessionStore(cache: cache)

        #expect(store.snapshot == .empty)
        #expect(store.snapshot.session == nil)
        #expect(store.snapshot.approval == nil)
    }

    @Test("Cached placeholder is ignored for runtime startup")
    func cachedPlaceholderIsIgnored() {
        let suite = "kiri-watch-dispatch-placeholder-\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suite)!
        defer { defaults.removePersistentDomain(forName: suite) }

        let cache = WatchStateCache(defaults: defaults, key: "snapshot")
        cache.save(.placeholder)

        let store = WatchSessionStore(cache: cache)

        #expect(store.snapshot == .empty)
        #expect(cache.loadSnapshot() == nil)
    }

    @Test("Ingest applies snapshot and buddy settings concurrently")
    func ingestAppliesBothKinds() throws {
        let suite = "kiri-watch-dispatch-\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suite)!
        defer { defaults.removePersistentDomain(forName: suite) }

        let cache = WatchStateCache(defaults: defaults, key: "snapshot")
        let store = WatchSessionStore(cache: cache)

        let snapshot = StateSnapshot.placeholder
        let settings = BuddySettings(
            activeManifestId: "com.kirifriends.bufo",
            buddyName: "Bufo",
            showsPreviewText: true,
            sharesAgentHealthContext: false
        )

        var context: [String: Any] = [:]
        context = try WatchConnectivityEnvelope.merge(kind: .stateSnapshot, value: snapshot, into: context)
        context = try WatchConnectivityEnvelope.merge(kind: .buddySettings, value: settings, into: context)
        store.ingest(applicationContext: context)

        #expect(store.snapshot == snapshot)
        #expect(store.buddySettings == settings)
    }

    @Test("Legacy snapshot-only context still updates the store")
    func legacyContextDecodes() throws {
        let suite = "kiri-watch-dispatch-legacy-\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suite)!
        defer { defaults.removePersistentDomain(forName: suite) }
        let cache = WatchStateCache(defaults: defaults, key: "snapshot")
        let store = WatchSessionStore(cache: cache)

        let snapshot = StateSnapshot.placeholder
        let legacy = try WatchConnectivityPayload.dictionary(from: snapshot)
        store.ingest(applicationContext: legacy)

        #expect(store.snapshot == snapshot)
        #expect(store.buddySettings == nil)
    }
}

#if canImport(WatchKit)
// `WatchSessionStore` exposes the same `ingest` API on the watchOS build,
// but tests run on macOS where the WatchKit branch compiles into a stub.
// The macOS branch covers the same surface; this comment intentionally
// documents that we tested via the stub.
#endif
