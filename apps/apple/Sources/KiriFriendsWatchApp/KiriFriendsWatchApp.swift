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
    @State private var snapshot = StateSnapshot.placeholder

    var body: some View {
        TabView {
            StatusView(snapshot: snapshot)
                .tabItem { Label("Status", systemImage: "waveform") }
            CommandsView(snapshot: snapshot)
                .tabItem { Label("Commands", systemImage: "command") }
            HistoryView()
                .tabItem { Label("History", systemImage: "clock") }
            SettingsView(snapshot: snapshot)
                .tabItem { Label("Settings", systemImage: "gear") }
        }
    }
}

struct StatusView: View {
    let snapshot: StateSnapshot

    var body: some View {
        ScrollView {
            StatusSummaryView(snapshot: snapshot)
                .padding()
        }
    }
}

struct CommandsView: View {
    let snapshot: StateSnapshot

    var body: some View {
        List {
            Button("Refresh") {}
            Button("Stop Task") {}
                .disabled(snapshot.session?.state != .running)
            Button("Approve") {}
                .disabled(snapshot.session?.state != .waitingForApproval)
        }
    }
}

struct HistoryView: View {
    var body: some View {
        List {
            Text("Recent CLI activity will appear here.")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }
}

struct SettingsView: View {
    let snapshot: StateSnapshot

    var body: some View {
        List {
            LabeledContent("Connection", value: snapshot.connectionState.rawValue)
            LabeledContent("Tool", value: snapshot.activeTool.rawValue)
        }
    }
}
