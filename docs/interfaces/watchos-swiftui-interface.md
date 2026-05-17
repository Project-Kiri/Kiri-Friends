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
    BuddyHomeView()
        .tabItem { Label("Status", systemImage: "waveform") }
    CommandsView()
        .tabItem { Label("Commands", systemImage: "command") }
    HistoryView()
        .tabItem { Label("History", systemImage: "clock") }
    SettingsView()
        .tabItem { Label("Settings", systemImage: "gear") }
}
```

## BuddyHomeView

Displays Kiri's current buddy state, concise speech, current task state, and the primary safe action.

```swift
struct BuddyHomeView: View {
    let snapshot: StateSnapshot
    let sendAction: (WatchAction) -> Void

    var body: some View {
        ScrollView {
            BuddyStageView(presentation: BuddyPresentationReducer.presentation(for: snapshot))
            BuddySpeechBubble(line: presentation.speech)
            ApprovalActionCard()
        }
    }
}
```

Double tap is reserved for the single visible primary action in the current scene, such as approving a non-private request. Wrist-down Always On state uses `isLuminanceReduced` for redaction and low-motion display; it is not a command input.

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
- CLI Host Bridge pairing status
- Full conversation history browsing
- Notification settings
- Watch app pairing status
- Buddy character pack import, validation, preview, and Watch sync
- Health summary privacy controls
