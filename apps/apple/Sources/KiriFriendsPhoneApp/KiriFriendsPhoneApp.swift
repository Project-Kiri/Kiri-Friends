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
    let relayMode: PhoneRelayMode

    init() {
        let relayMode = PhoneRelayMode.current()
        let downlink = relayMode.client
        let watch = PhoneWatchConnectivityController()
        let appGroup = AppGroupSnapshotStore(suiteName: "group.com.kirifriends.shared")
        self.relayMode = relayMode
        self.runtime = BridgeRuntime(
            client: downlink,
            watchController: watch,
            appGroupStore: appGroup,
            userId: relayMode.userId,
            macDeviceId: relayMode.macDeviceId
        )
        let defaultTheme = BundledBuddyThemeRegistry.defaultTheme.manifest
        self.manualSettings = BuddySettings(
            activeManifestId: defaultTheme.identifier,
            buddyName: defaultTheme.displayName,
            showsPreviewText: false,
            sharesAgentHealthContext: false
        )
        self.runtime.setSharesHealthContext(manualSettings.sharesAgentHealthContext)
    }

    func start() async {
        await runtime.start()
    }

    func updateBuddySettings(_ next: BuddySettings) {
        manualSettings = next
        runtime.setSharesHealthContext(next.sharesAgentHealthContext)
        // The settings sync helper writes through to WC under the
        // `buddy.settings` envelope slot.
        try? runtime.publishBuddySettings(next)
    }
}

struct PhoneRelayConfiguration {
    var downlink: HTTPRelayDownlinkClient.Configuration
    var userId: String
    var macDeviceId: String?

    static func current(environment: [String: String] = ProcessInfo.processInfo.environment) -> PhoneRelayConfiguration? {
        guard
            let base = environment["KIRI_RELAY_URL"].flatMap(URL.init(string:)),
            let token = environment["KIRI_DEVICE_TOKEN"],
            let userId = environment["KIRI_USER_ID"]
        else {
            return nil
        }
        return PhoneRelayConfiguration(
            downlink: HTTPRelayDownlinkClient.Configuration(
                baseURL: base,
                deviceToken: token,
                userId: userId
            ),
            userId: userId,
            macDeviceId: environment["KIRI_MAC_DEVICE_ID"]
        )
    }
}

enum PhoneRelayMode {
    case http(PhoneRelayConfiguration)
    case inMemoryDevelopment
    case unavailable

    static func current(environment: [String: String] = ProcessInfo.processInfo.environment) -> PhoneRelayMode {
        if let configuration = PhoneRelayConfiguration.current(environment: environment) {
            return .http(configuration)
        }
        if environment["KIRI_USE_IN_MEMORY_RELAY"] == "1" {
            return .inMemoryDevelopment
        }
        return .unavailable
    }

    var client: any RelayDownlinkClient {
        switch self {
        case .http(let configuration):
            return HTTPRelayDownlinkClient(configuration: configuration.downlink)
        case .inMemoryDevelopment:
            return InMemoryRelayDownlinkClient()
        case .unavailable:
            return RelayUnavailableDownlinkClient()
        }
    }

    var userId: String {
        switch self {
        case .http(let configuration):
            return configuration.userId
        case .inMemoryDevelopment:
            return "local-dev"
        case .unavailable:
            return "unconfigured"
        }
    }

    var macDeviceId: String? {
        switch self {
        case .http(let configuration):
            return configuration.macDeviceId
        case .inMemoryDevelopment:
            return "local-mac"
        case .unavailable:
            return nil
        }
    }

    var displayName: String {
        switch self {
        case .http:
            return "Cloud Relay"
        case .inMemoryDevelopment:
            return "Local in-memory"
        case .unavailable:
            return "Not configured"
        }
    }

    var configurationHint: String? {
        switch self {
        case .http:
            return nil
        case .inMemoryDevelopment:
            return "Development mode only. Set KIRI_RELAY_URL, KIRI_DEVICE_TOKEN, and KIRI_USER_ID for real relay traffic."
        case .unavailable:
            return "Set KIRI_RELAY_URL, KIRI_DEVICE_TOKEN, and KIRI_USER_ID to connect the iPhone companion to Cloud Relay."
        }
    }
}

struct PhoneCompanionRootView: View {
    let model: PhoneAppModel

    var body: some View {
        NavigationStack {
            List {
                Section("Relay") {
                    LabeledContent("Mode", value: model.relayMode.displayName)
                    LabeledContent("Connection", value: model.runtime.store.latestSnapshot.connectionState.rawValue)
                    LabeledContent("Active Tool", value: model.runtime.store.latestSnapshot.activeTool.rawValue)
                    LabeledContent("Sessions", value: "\(model.runtime.store.latestSnapshot.sessions.count)")
                    if let hint = model.relayMode.configurationHint {
                        Text(hint)
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    }
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
                        BuddyLibraryView(model: model)
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

struct BuddyLibraryView: View {
    @Bindable var model: PhoneAppModel

    var body: some View {
        List {
            Section("Bundled Themes") {
                ForEach(BundledBuddyThemeRegistry.all) { theme in
                    Button {
                        var next = model.manualSettings
                        next.activeManifestId = theme.manifest.identifier
                        next.buddyName = theme.manifest.displayName
                        model.updateBuddySettings(next)
                    } label: {
                        HStack {
                            VStack(alignment: .leading, spacing: 4) {
                                Text(theme.manifest.displayName)
                                    .font(.body)
                                Text("\(theme.manifest.states.count) states · \(theme.manifest.author ?? "Unknown author")")
                                    .font(.footnote)
                                    .foregroundStyle(.secondary)
                            }
                            Spacer()
                            if model.manualSettings.activeManifestId == theme.manifest.identifier {
                                Image(systemName: "checkmark")
                                    .foregroundStyle(.tint)
                            }
                        }
                    }
                }
            }

            Section("License") {
                Text("Bundled character packs are available now and sync to Watch through buddy settings. They are derived from clawd-on-desk and ship under AGPL-3.0.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
        }
        .navigationTitle("Characters")
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
