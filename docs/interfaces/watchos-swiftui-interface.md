# watchOS SwiftUI Interface

## App Entry Point

```swift
@main
struct KiriFriendsWatchApp: App {
    var body: some Scene {
        WindowGroup {
            ContentView()
        }
    }
}
```

## ContentView Structure

`ContentView` is a `TabView` with four tabs:

```swift
TabView {
    StatusView()
        .tabItem { Label("Status", systemImage: "waveform") }
    CommandsView()
        .tabItem { Label("Commands", systemImage: "command") }
    HistoryView()
        .tabItem { Label("History", systemImage: "clock") }
    SettingsView()
        .tabItem { Label("Settings", systemImage: "gear") }
}
```

## StatusView

Displays the active CLI tool, current task, and connection status.

```swift
struct StatusView: View {
    @State private var status: CLIStatus

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 8) {
                StatusHeaderView(status: status)
                TaskCardView(task: status.currentTask)
                ConnectionBadgeView(state: status.connectionState)
            }
            .padding()
        }
    }
}
```

## Complication Views

Complication views are SwiftUI views conforming to `Widget` protocol:

```swift
struct StatusComplication: Widget {
    var body: some WidgetConfiguration {
        AccessoryCornerConfiguration(
            kind: "com.kirifriends.status",
            provider: StatusProvider()
        ) { entry in
            StatusCornerView(entry: entry)
        }
        .configurationDisplayName("Kiri Status")
        .description("Shows your active CLI status")
    }
}
```

## iPhone Companion

The iPhone companion app (`KiriFriendsBridge`) provides:

- Cloud Relay connection management
- Mac bridge pairing status
- Full conversation history browsing
- Notification settings
- Watch app pairing status
