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
    SessionsView()
        .tabItem { Label("Sessions", systemImage: "rectangle.stack") }
    CommandsView()
        .tabItem { Label("Commands", systemImage: "command") }
    SettingsView()
        .tabItem { Label("Settings", systemImage: "gear") }
}
```

## BuddyHomeView

Displays Kiri's current buddy state, concise speech, current task state, and hook-driven pending actions.

```swift
struct BuddyHomeView: View {
    let snapshot: StateSnapshot
    let sendAction: (WatchAction) -> Void

    var body: some View {
        ScrollView {
            BuddyStageView(presentation: BuddyPresentationReducer.presentation(for: snapshot))
            BuddySpeechBubble(line: presentation.speech)
            PendingActionStrip()
        }
    }
}
```

Pending actions only appear for hook-triggered states. `waitingForApproval`
shows `Approve` and `Deny`; `waitingForInput` shows `Reply`. The highlighted
action receives SwiftUI `handGestureShortcut(.primaryAction)`, so Apple Watch
Double Tap selects the highlighted option while the touch button remains the
fallback. Wrist rotation is interpreted with foreground-only Core Motion device
motion updates; it switches the highlighted option with threshold, cooldown,
and neutral reset logic to avoid repeated triggers. Wrist-down Always On state
uses `isLuminanceReduced` for redaction and low-motion display; it is not a
command input and never starts motion updates.

On first launch or after clearing local state, the Watch starts from a neutral
empty snapshot instead of the sample approval fixture. Cached copies of the
sample `StateSnapshot.placeholder` are discarded so mock text such as
`Run tests` never appears in the runtime UI.

## Commands and Health

The Commands tab uses the same `PendingActionStrip` mapping as Status. It sends
`approval.allow`, `approval.deny`, and `prompt.sendQuick` as `WatchAction`
messages only when the selected session is in a hook-driven pending state.
Each action is session-scoped when a session is selected; otherwise it falls
back to the priority-resolved primary session.

The Settings tab can send a low-sensitivity `health.signal.summary` through
WatchConnectivity. The iPhone only folds this into `StateSnapshot` when the
user enables health context sharing in the iPhone privacy settings.

The Watch app is an iPhone companion app, not a standalone watch-only runtime.
Its bundle identifier must stay under the iPhone prefix
(`com.kirifriends.phone.watchapp`) and the iPhone target embeds the Watch app so
`WCSession` reports `isWatchAppInstalled` before application context delivery.

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

For local and TestFlight-style relay wiring, the iPhone companion can be
configured with `KIRI_RELAY_URL`, `KIRI_DEVICE_TOKEN`, `KIRI_USER_ID`, and
`KIRI_MAC_DEVICE_ID`. Without the required relay values it reports an
unconfigured relay state instead of using an in-memory fake. Local development
can opt into the in-memory client with `KIRI_USE_IN_MEMORY_RELAY=1`.
