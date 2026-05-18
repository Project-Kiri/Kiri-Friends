import Foundation
import KiriFriendsBridge
import KiriFriendsCore
@testable import KiriFriendsPhoneApp
@testable import KiriFriendsWidgets
import Testing

@Test func phoneRelayModeRequiresExplicitInMemoryFlag() {
    #expect(isUnavailable(PhoneRelayMode.current(environment: [:])))
    #expect(isInMemoryDevelopment(PhoneRelayMode.current(environment: ["KIRI_USE_IN_MEMORY_RELAY": "1"])))

    let configured = PhoneRelayMode.current(environment: [
        "KIRI_RELAY_URL": "https://relay.example.test",
        "KIRI_DEVICE_TOKEN": "token",
        "KIRI_USER_ID": "user-1",
        "KIRI_MAC_DEVICE_ID": "mac-1",
    ])

    guard case .http(let configuration) = configured else {
        Issue.record("Expected HTTP relay mode")
        return
    }
    #expect(configuration.userId == "user-1")
    #expect(configuration.macDeviceId == "mac-1")
}

@Test func unavailableRelayClientReportsRealOfflineState() async {
    let client = RelayUnavailableDownlinkClient()

    #expect(client.startupConnectionState == .relayUnavailable)
    await #expect(throws: RelayUnavailableDownlinkClient.UnavailableError.missingConfiguration) {
        try await client.sendRequest(
            RelayRequestEnvelope(
                targetDeviceId: "mac-1",
                kind: WatchActionKind.statusRefresh.rawValue,
                expiresAt: Date(timeIntervalSince1970: 1),
                idempotencyKey: "request-1"
            )
        )
    }
}

@Test func widgetRuntimeFallbackNeverUsesPreviewPlaceholder() {
    #expect(KiriFriendsStatusProvider.runtimeSnapshot(from: nil) == .empty)

    let suiteName = "kiri-widget-runtime-\(UUID().uuidString)"
    let defaults = UserDefaults(suiteName: suiteName)!
    defer { defaults.removePersistentDomain(forName: suiteName) }

    let store = AppGroupSnapshotStore(defaults: defaults)
    store.saveComplicationSnapshot(.placeholder)

    #expect(KiriFriendsStatusProvider.runtimeSnapshot(from: store) == .empty)
}

private func isUnavailable(_ mode: PhoneRelayMode) -> Bool {
    if case .unavailable = mode { return true }
    return false
}

private func isInMemoryDevelopment(_ mode: PhoneRelayMode) -> Bool {
    if case .inMemoryDevelopment = mode { return true }
    return false
}
