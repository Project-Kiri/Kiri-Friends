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
    @State private var activeApprovalPrompt: ApprovalPrompt?
    @State private var presentedApprovalIDs: Set<String> = []

    private var activeTheme: BundledBuddyTheme {
        BundledBuddyThemeRegistry.theme(identifier: watchStore.buddySettings?.activeManifestId)
    }

    private var showsCommandsTab: Bool {
        snapshotSessions(from: watchStore.snapshot).contains {
            !$0.commandOptionsExcludingApproval.isEmpty
        }
    }

    var body: some View {
        TabView {
            StatusView(
                snapshot: watchStore.snapshot,
                theme: activeTheme
            )
            .tabItem { Label("Status", systemImage: "waveform") }

            SessionsView(
                snapshot: watchStore.snapshot,
                selection: $selectedSessionId,
                openApproval: presentApprovalPrompt
            )
            .tabItem { Label("Sessions", systemImage: "rectangle.stack") }

            if showsCommandsTab {
                CommandsView(
                    snapshot: watchStore.snapshot,
                    selectedSessionId: $selectedSessionId,
                    sendAction: watchStore.sendAction
                )
                .tabItem { Label("Commands", systemImage: "command") }
            }

            SettingsView(
                snapshot: watchStore.snapshot,
                buddySettings: watchStore.buddySettings,
                sendHealthSummary: watchStore.sendHealthSummary
            )
                .tabItem { Label("Settings", systemImage: "gear") }
        }
        .sheet(item: $activeApprovalPrompt) { prompt in
            ApprovalPromptCard(
                prompt: prompt,
                sendAction: { action in sendApprovalAction(action, prompt: prompt) }
            )
            .interactiveDismissDisabled()
        }
        .onAppear {
            watchStore.activate()
            if selectedSessionId == nil {
                selectedSessionId = watchStore.snapshot.session?.id
            }
            presentApprovalPromptIfNeeded(for: watchStore.snapshot)
        }
        .onChange(of: watchStore.snapshot.session?.id) { _, newValue in
            if selectedSessionId == nil { selectedSessionId = newValue }
        }
        .onChange(of: watchStore.snapshot) { _, newValue in
            presentApprovalPromptIfNeeded(for: newValue)
        }
    }

    private func presentApprovalPromptIfNeeded(for snapshot: StateSnapshot) {
        guard let prompt = ApprovalPrompt(snapshot: snapshot) else {
            activeApprovalPrompt = nil
            return
        }

        guard !presentedApprovalIDs.contains(prompt.id) else { return }

        presentedApprovalIDs.insert(prompt.id)
        activeApprovalPrompt = prompt
        KiriHaptics.approvalRequired()
    }

    private func presentApprovalPrompt(for session: CLISessionSummary) {
        selectedSessionId = session.id
        guard let prompt = ApprovalPrompt(snapshot: watchStore.snapshot, session: session) else {
            KiriHaptics.selectionChanged()
            return
        }

        activeApprovalPrompt = prompt
        KiriHaptics.selectionChanged()
    }

    private func sendApprovalAction(_ action: WatchActionKind, prompt: ApprovalPrompt) {
        switch action {
        case .approvalAllow:
            KiriHaptics.approvalAccepted()
        case .approvalDeny:
            KiriHaptics.approvalDenied()
        case .taskStop, .promptSendQuick, .statusRefresh:
            KiriHaptics.selectionChanged()
        }

        watchStore.sendAction(
            WatchAction(
                action: action,
                sessionId: prompt.sessionId,
                approvalId: prompt.approvalId,
                createdAt: .now
            )
        )
        activeApprovalPrompt = nil
    }
}

private func snapshotSessions(from snapshot: StateSnapshot) -> [CLISessionSummary] {
    if !snapshot.sessions.isEmpty { return snapshot.sessions }
    if let session = snapshot.session { return [session] }
    return []
}

private extension CLISessionSummary {
    var commandOptionsExcludingApproval: [PendingWatchActionOption] {
        switch state {
        case .waitingForInput:
            return [
                PendingWatchActionOption(
                    action: .promptSendQuick,
                    title: "Reply",
                    accessibilityHint: "Sends a quick reply to the active session."
                ),
            ]
        case .waitingForApproval, .running, .idle, .failed, .completed, .unknown:
            return []
        }
    }
}

private struct ApprovalPrompt: Identifiable, Equatable {
    var id: String
    var sessionId: String?
    var approvalId: String?
    var title: String
    var summary: String
    var sensitivity: PayloadSensitivity

    init?(snapshot: StateSnapshot) {
        if let approval = snapshot.approval {
            id = approval.id
            sessionId = approval.sessionId
            approvalId = approval.id
            title = approval.title
            summary = approval.summary
            sensitivity = approval.sensitivity
            return
        }

        guard let session = snapshot.session, session.state == .waitingForApproval else {
            return nil
        }
        id = "approval-\(session.id)"
        sessionId = session.id
        approvalId = nil
        title = session.title
        summary = session.summary
        sensitivity = session.sensitivity
    }

    init?(snapshot: StateSnapshot, session: CLISessionSummary) {
        if let approval = snapshot.approval, approval.sessionId == session.id {
            id = approval.id
            sessionId = approval.sessionId
            approvalId = approval.id
            title = approval.title
            summary = approval.summary
            sensitivity = approval.sensitivity
            return
        }

        guard session.state == .waitingForApproval else {
            return nil
        }
        id = "approval-\(session.id)"
        sessionId = session.id
        approvalId = nil
        title = session.title
        summary = session.summary
        sensitivity = session.sensitivity
    }

    var options: [PendingWatchActionOption] {
        [
            PendingWatchActionOption(
                action: .approvalAllow,
                title: "Approve",
                accessibilityHint: "Approves the current CLI action."
            ),
            PendingWatchActionOption(
                action: .approvalDeny,
                title: "Deny",
                isDestructive: true,
                accessibilityHint: "Denies the current CLI action."
            ),
        ]
    }

    var displayText: String {
        let trimmedSummary = summary.trimmingCharacters(in: .whitespacesAndNewlines)
        if !trimmedSummary.isEmpty { return trimmedSummary }
        return title
    }
}

private struct ApprovalPromptCard: View {
    let prompt: ApprovalPrompt
    let sendAction: (WatchActionKind) -> Void

    var body: some View {
        VStack(spacing: 12) {
            Text(prompt.displayText)
                .font(.title3)
                .lineLimit(3)
                .minimumScaleFactor(0.78)
                .multilineTextAlignment(.leading)
                .privacySensitive(prompt.sensitivity != .none)
                .frame(maxWidth: .infinity, minHeight: 68, alignment: .leading)
                .padding(14)
                .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 24, style: .continuous))
                .overlay {
                    RoundedRectangle(cornerRadius: 24, style: .continuous)
                        .stroke(.white.opacity(0.14), lineWidth: 1)
                }

            PendingActionStrip(
                options: prompt.options,
                layout: .vertical,
                sendAction: sendAction
            )
        }
        .padding(.horizontal, 10)
        .frame(maxWidth: .infinity)
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Approval needed for \(prompt.displayText)")
    }
}

struct StatusView: View {
    let snapshot: StateSnapshot
    let theme: BundledBuddyTheme

    var body: some View {
        // Status is intentionally just the buddy stage. The agent label,
        // explicit state text, "Relay connected" badge, and "+N sessions"
        // hint were removed so the primary action fits the first screen
        // (watchos-design-guidelines W-GL-01 / W-NV-05). Per-agent context
        // and additional sessions live one swipe away on the Sessions tab.
        BuddyHomeView(snapshot: snapshot, theme: theme)
    }
}

struct SessionsView: View {
    let snapshot: StateSnapshot
    @Binding var selection: String?
    let openApproval: (CLISessionSummary) -> Void

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
        let list = List(snapshot.sessions) { session in
            Button {
                selection = session.id
                if session.state == .waitingForApproval {
                    openApproval(session)
                } else {
                    KiriHaptics.selectionChanged()
                }
            } label: {
                sessionRow(session)
            }
            .buttonStyle(.plain)
            .accessibilityHint(accessibilityHint(for: session))
        }
        #if os(watchOS)
        list.listStyle(.carousel)
        #else
        list
        #endif
    }

    private func sessionRow(_ session: CLISessionSummary) -> some View {
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
            Spacer(minLength: 0)
            if session.state == .waitingForApproval {
                Image(systemName: "chevron.right")
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(.secondary)
            }
        }
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

    private func accessibilityHint(for session: CLISessionSummary) -> String {
        switch session.state {
        case .waitingForApproval:
            return "Opens the approval actions for this session."
        case .waitingForInput:
            return "Selects this session for reply actions."
        case .running, .idle, .failed, .completed, .unknown:
            return "Selects this session."
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
        let options = targetSession?.commandOptionsExcludingApproval ?? []
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
