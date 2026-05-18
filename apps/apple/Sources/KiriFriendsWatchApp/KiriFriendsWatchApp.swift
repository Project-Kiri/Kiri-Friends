import KiriFriendsCore
import KiriFriendsWatchKit
import SwiftUI

@main
struct KiriFriendsWatchApp: App {
    var body: some Scene {
        WindowGroup {
            ContentView()
        }
    }
}

struct ContentView: View {
    @State private var watchStore = WatchSessionStore()
    @State private var selectedSessionId: String?

    private var activeTheme: BundledBuddyTheme {
        BundledBuddyThemeRegistry.theme(identifier: watchStore.buddySettings?.activeManifestId)
    }

    var body: some View {
        TabView {
            StatusView(
                snapshot: watchStore.snapshot,
                theme: activeTheme,
                sendAction: watchStore.sendAction
            )
            .tabItem { Label("Status", systemImage: "waveform") }

            SessionsView(
                snapshot: watchStore.snapshot,
                selection: $selectedSessionId
            )
            .tabItem { Label("Sessions", systemImage: "rectangle.stack") }

            CommandsView(
                snapshot: watchStore.snapshot,
                selectedSessionId: $selectedSessionId,
                sendAction: watchStore.sendAction
            )
            .tabItem { Label("Commands", systemImage: "command") }

            SettingsView(
                snapshot: watchStore.snapshot,
                buddySettings: watchStore.buddySettings,
                sendHealthSummary: watchStore.sendHealthSummary
            )
                .tabItem { Label("Settings", systemImage: "gear") }
        }
        .onAppear {
            watchStore.activate()
            if selectedSessionId == nil {
                selectedSessionId = watchStore.snapshot.session?.id
            }
        }
        .onChange(of: watchStore.snapshot.session?.id) { _, newValue in
            if selectedSessionId == nil { selectedSessionId = newValue }
        }
    }
}

struct StatusView: View {
    let snapshot: StateSnapshot
    let theme: BundledBuddyTheme
    let sendAction: (WatchAction) -> Void

    var body: some View {
        // Status is intentionally just the buddy stage. The agent label,
        // explicit state text, "Relay connected" badge, and "+N sessions"
        // hint were removed so the primary action fits the first screen
        // (watchos-design-guidelines W-GL-01 / W-NV-05). Per-agent context
        // and additional sessions live one swipe away on the Sessions tab.
        BuddyHomeView(snapshot: snapshot, theme: theme, sendAction: sendAction)
    }
}

struct SessionsView: View {
    let snapshot: StateSnapshot
    @Binding var selection: String?

    var body: some View {
        sessionList
            .overlay(alignment: .center) {
                if snapshot.sessions.isEmpty {
                    Text("No active sessions")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
    }

    @ViewBuilder
    private var sessionList: some View {
        let list = List(snapshot.sessions, selection: $selection) { session in
            HStack(spacing: 8) {
                Circle()
                    .fill(color(for: session.state))
                    .frame(width: 8, height: 8)
                if let tool = session.tool {
                    Image(systemName: tool.symbolName)
                        .symbolRenderingMode(.hierarchical)
                        .frame(width: 18)
                }
                VStack(alignment: .leading, spacing: 2) {
                    Text(session.title)
                        .font(.caption.weight(.semibold))
                        .lineLimit(1)
                    Text(session.state.rawValue)
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }
            .tag(session.id)
        }
        #if os(watchOS)
        list.listStyle(.carousel)
        #else
        list
        #endif
    }

    private func color(for state: SessionState) -> Color {
        switch state {
        case .waitingForApproval: return .orange
        case .failed: return .red
        case .running: return .blue
        case .waitingForInput: return .purple
        case .completed: return .green
        case .idle, .unknown: return .gray
        }
    }
}

struct CommandsView: View {
    let snapshot: StateSnapshot
    @Binding var selectedSessionId: String?
    let sendAction: (WatchAction) -> Void

    private var targetSession: CLISessionSummary? {
        if let selectedSessionId,
           let found = snapshot.sessions.first(where: { $0.id == selectedSessionId })
        {
            return found
        }
        return snapshot.session
    }

    var body: some View {
        List {
            if !snapshot.sessions.isEmpty {
                sessionPicker
            }
            actionButtons
        }
    }

    @ViewBuilder
    private var actionButtons: some View {
        let options = PendingWatchActionOption.options(for: snapshot, targetSession: targetSession)
        if options.isEmpty {
            Text("No actions pending")
                .font(.caption)
                .foregroundStyle(.secondary)
                .frame(maxWidth: .infinity, alignment: .center)
                .listRowBackground(Color.clear)
        } else {
            PendingActionStrip(options: options, sendAction: send)
        }
    }

    @ViewBuilder
    private var sessionPicker: some View {
        let picker = Picker("Target", selection: targetSelection) {
            ForEach(snapshot.sessions) { session in
                Text("\(session.tool?.displayName ?? "Unknown") · \(session.state.rawValue)")
                    .tag(session.id as String?)
            }
        }
        #if os(watchOS)
        picker.pickerStyle(.navigationLink)
        #else
        picker
        #endif
    }

    private var targetSelection: Binding<String?> {
        Binding(
            get: { selectedSessionId ?? snapshot.session?.id },
            set: { selectedSessionId = $0 }
        )
    }

    private func send(_ action: WatchActionKind) {
        let session = targetSession
        sendAction(
            WatchAction(
                action: action,
                sessionId: session?.id ?? snapshot.approval?.sessionId,
                approvalId: snapshot.approval?.id,
                createdAt: .now
            )
        )
    }
}

struct SettingsView: View {
    let snapshot: StateSnapshot
    let buddySettings: BuddySettings?
    let sendHealthSummary: (HealthSignalSummary) -> Void

    @State private var healthStatus: String?

    private var activeThemeName: String {
        BundledBuddyThemeRegistry
            .theme(identifier: buddySettings?.activeManifestId)
            .manifest
            .displayName
    }

    var body: some View {
        List {
            LabeledContent("Connection", value: snapshot.connectionState.rawValue)
            LabeledContent("Sessions", value: "\(snapshot.sessions.count)")
            LabeledContent("Health", value: snapshot.healthSummary?.activityState.rawValue ?? "unavailable")
            LabeledContent("Theme", value: activeThemeName)
            if let buddySettings {
                LabeledContent("Buddy", value: buddySettings.buddyName)
                LabeledContent("Preview", value: buddySettings.showsPreviewText ? "on" : "off")
            }
            Button("Send Health Summary") {
                Task { await sendCurrentHealthSummary() }
            }
            if let healthStatus {
                Text(healthStatus)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
        }
    }

    private func sendCurrentHealthSummary() async {
        #if canImport(HealthKit)
        let provider = HealthSignalProvider()
        do {
            try await provider.requestAuthorization()
            let summary = await provider.currentSummary()
            sendHealthSummary(summary)
            healthStatus = "Health summary sent"
        } catch {
            healthStatus = "Health data unavailable"
        }
        #else
        sendHealthSummary(.placeholder)
        healthStatus = "Health summary sent"
        #endif
    }
}
