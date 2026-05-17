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
                sendAction: watchStore.sendAction,
                onAdditionalSessionsTapped: { /* TabView handles selection externally */ }
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

            SettingsView(snapshot: watchStore.snapshot, buddySettings: watchStore.buddySettings)
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
    let onAdditionalSessionsTapped: () -> Void

    var body: some View {
        VStack(spacing: 8) {
            if let tool = snapshot.session?.tool {
                Label(tool.displayName, systemImage: tool.symbolName)
                    .font(.caption.weight(.semibold))
                    .symbolRenderingMode(.hierarchical)
            }
            BuddyHomeView(snapshot: snapshot, theme: theme, sendAction: sendAction)
            if snapshot.additionalSessionCount > 0 {
                Text("+\(snapshot.additionalSessionCount) other sessions")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .onTapGesture(perform: onAdditionalSessionsTapped)
            }
        }
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

            Button("Refresh") {
                send(.statusRefresh)
            }
            Button("Stop Task") {
                send(.taskStop)
            }
            .disabled(targetSession?.state != .running)
            Button("Approve") {
                send(.approvalAllow)
            }
            .disabled(targetSession?.state != .waitingForApproval)
            Button("Deny") {
                send(.approvalDeny)
            }
            .disabled(targetSession?.state != .waitingForApproval)
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
        }
    }
}
