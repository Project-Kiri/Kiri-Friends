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

Displays Kiri's current buddy state in a fixed, non-scrolling glanceable
layout. The visible buddy art is vertically centered. CLI task context such as
`approval.summary`, `session.summary`, or `session.title` stays in the approval
sheet, Sessions tab, and complications; it is not rendered as pet speech. The
Status page hides the speech row unless a future snapshot field carries explicit
buddy utterance text.

A microphone button below the buddy art sends a `voice.inputRequest` watch action
to the iPhone companion. The iPhone uses `SFSpeechRecognizer` to capture speech
from its own microphone, then automatically forwards the transcribed text as a
`prompt.sendQuick` action. This bypasses the watchOS limitation that
`SFSpeechRecognizer` is not available on Apple Watch.

When transcription completes, the iPhone echoes the recognized text back to the
watch via a `voice.transcription` `sendMessage` payload. The watch displays this
as a `TranscriptionBadge` below the speech bubble so the user sees what was
understood before it is sent to the CLI host.

The buddy animation path mirrors `clawd-on-desk` rather than applying a generic
scale loop to a single image. `BundledBuddyTheme.animationSpec` carries the
desktop theme semantics (`states`, `workingTiers`, `idleAnimations`,
`timings`, and layout metadata). `BuddyAnimationResolver` maps the current
`StateSnapshot` into a desktop visual state such as `notification`, `working`,
or `error`, and `BuddyAnimationPlayer` plays the generated PNG frame sequence
from `Resources/BuddyAnimationFrames`. Static Asset Catalog SVGs remain a
fallback only when a frame manifest is unavailable.

```swift
struct BuddyHomeView: View {
    let snapshot: StateSnapshot
    let voiceTranscription: String?

    var body: some View {
        VStack(spacing: 6) {
            BuddyStageView(
                snapshot: snapshot,
                presentation: BuddyPresentationReducer.presentation(for: snapshot)
            )
            BuddySpeechBubble(line: presentation.speech)
            if let transcription = voiceTranscription, !transcription.isEmpty {
                TranscriptionBadge(text: transcription)
            }
            ConnectionBadgeView(connectionState: snapshot.connectionState)
        }
    }
}
```

Approval actions are not embedded in the Status page. When a new approval
arrives, `ContentView` presents a native SwiftUI `sheet(item:)` using the
approval as the `Identifiable` data source. The sheet uses a Long Look-style
vertical layout: command summary card first, then large full-width
`Approve` / `Deny` action pills. The same `PendingActionStrip` remains
available inside the sheet in vertical mode. The highlighted action receives SwiftUI
`handGestureShortcut(.primaryAction)`, so Apple Watch Double Tap selects the
highlighted option while the touch button remains the fallback. Wrist rotation
is interpreted with foreground-only Core Motion device motion updates; it
switches the highlighted option with threshold, cooldown, and neutral reset
logic to avoid repeated triggers. Wrist-down Always On state uses
`isLuminanceReduced` for redaction and low-motion display; it is not a command
input and never starts motion updates.

On first launch or after clearing local state, the Watch starts from a neutral
empty snapshot instead of the sample approval fixture. Cached copies of the
sample `StateSnapshot.placeholder` are discarded so mock text such as
`Run tests` never appears in the runtime UI.

## Commands and Health

The Sessions tab doubles as the multi-session entry point. Tapping a
`waitingForApproval` row opens that session's approval sheet directly; tapping
other rows only selects the target session for non-approval actions.

The Commands tab is only shown when a non-approval hook action is pending, such
as `waitingForInput` quick replies. Approval actions are intentionally excluded
from Commands so the Watch never shows a second `Approve` / `Deny` page for the
same request.

The Watch app sends a low-sensitivity `health.signal.summary` through
WatchConnectivity automatically on a five-minute heartbeat while the app is
active. The iPhone only folds this into `StateSnapshot` when the user enables
health context sharing in the iPhone privacy settings.

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
