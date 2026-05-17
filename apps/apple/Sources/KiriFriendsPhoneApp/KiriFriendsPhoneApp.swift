import Foundation
import KiriFriendsBridge
import KiriFriendsCore
import KiriFriendsWatchKit
import SwiftUI

@main
struct KiriFriendsPhoneApp: App {
    @State private var model = PhoneAppModel()

    var body: some Scene {
        WindowGroup {
            PhoneCompanionRootView(model: model)
                .task {
                    await model.start()
                }
        }
    }
}

@Observable
@MainActor
final class PhoneAppModel {
    let runtime: BridgeRuntime
    var manualSettings: BuddySettings

    private let downlink: InMemoryRelayDownlinkClient

    init() {
        let downlink = InMemoryRelayDownlinkClient()
        self.downlink = downlink
        let watch = PhoneWatchConnectivityController()
        let appGroup = AppGroupSnapshotStore(suiteName: "group.com.kirifriends.shared")
        self.runtime = BridgeRuntime(
            client: downlink,
            watchController: watch,
            appGroupStore: appGroup,
            userId: "local-dev",
            macDeviceId: "local-mac"
        )
        let defaultTheme = BundledBuddyThemeRegistry.defaultTheme.manifest
        self.manualSettings = BuddySettings(
            activeManifestId: defaultTheme.identifier,
            buddyName: defaultTheme.displayName,
            showsPreviewText: false,
            sharesAgentHealthContext: false
        )
    }

    func start() async {
        await runtime.start()
    }

    func updateBuddySettings(_ next: BuddySettings) {
        manualSettings = next
        // The settings sync helper writes through to WC under the
        // `buddy.settings` envelope slot.
        try? runtime.publishBuddySettings(next)
    }
}

struct PhoneCompanionRootView: View {
    let model: PhoneAppModel

    var body: some View {
        NavigationStack {
            List {
                Section("Relay") {
                    LabeledContent("Connection", value: model.runtime.store.latestSnapshot.connectionState.rawValue)
                    LabeledContent("Active Tool", value: model.runtime.store.latestSnapshot.activeTool.rawValue)
                    LabeledContent("Sessions", value: "\(model.runtime.store.latestSnapshot.sessions.count)")
                }

                Section("Sessions") {
                    if model.runtime.store.latestSnapshot.sessions.isEmpty {
                        Text("No CLI sessions reported yet.")
                            .foregroundStyle(.secondary)
                            .font(.footnote)
                    } else {
                        ForEach(model.runtime.store.latestSnapshot.sessions) { session in
                            VStack(alignment: .leading, spacing: 4) {
                                HStack {
                                    Text(session.tool?.displayName ?? "Unknown")
                                        .font(.footnote.monospaced())
                                    Spacer()
                                    Text(session.state.rawValue)
                                        .font(.caption2)
                                        .foregroundStyle(.secondary)
                                }
                                Text(session.title)
                                    .font(.body)
                            }
                        }
                    }
                }

                Section("Buddy") {
                    NavigationLink("Theme") {
                        BuddyThemeSettingsView(model: model)
                    }
                    NavigationLink("Character Library") {
                        BuddyLibraryPlaceholderView()
                    }
                    NavigationLink("Privacy") {
                        HealthContextSettingsView(model: model)
                    }
                }
            }
            .navigationTitle("Kiri Friends")
        }
    }
}

struct BuddyLibraryPlaceholderView: View {
    var body: some View {
        ContentUnavailableView(
            "Character Library",
            systemImage: "photo.stack",
            description: Text("Import and sync Kiri character packs from iPhone.")
        )
    }
}

struct BuddyThemeSettingsView: View {
    @Bindable var model: PhoneAppModel

    var body: some View {
        Form {
            Picker(
                "Buddy theme",
                selection: Binding(
                    get: { model.manualSettings.activeManifestId },
                    set: { newValue in
                        var next = model.manualSettings
                        next.activeManifestId = newValue
                        model.updateBuddySettings(next)
                    }
                )
            ) {
                ForEach(BundledBuddyThemeRegistry.all) { theme in
                    Text(theme.manifest.displayName)
                        .tag(theme.manifest.identifier)
                }
            }
            .pickerStyle(.inline)

            Section {
                Text("Bundled themes are derived from clawd-on-desk and ship under AGPL-3.0.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
        }
        .navigationTitle("Theme")
    }
}

struct HealthContextSettingsView: View {
    @Bindable var model: PhoneAppModel

    var body: some View {
        Form {
            Toggle(
                "Share wellness summaries with agent",
                isOn: Binding(
                    get: { model.manualSettings.sharesAgentHealthContext },
                    set: { newValue in
                        var next = model.manualSettings
                        next.sharesAgentHealthContext = newValue
                        model.updateBuddySettings(next)
                    }
                )
            )
            Text("Raw heart-rate samples stay on device. Kiri can share only a low-sensitivity summary when this is enabled.")
                .font(.footnote)
                .foregroundStyle(.secondary)
        }
        .navigationTitle("Privacy")
    }
}
