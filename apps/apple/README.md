# Kiri Friends Apple

This directory contains the SwiftPM workspace for Apple-platform code:

- `KiriFriendsCore` — shared domain models and protocol types.
- `KiriFriendsWatchKit` — reusable watchOS SwiftUI components.
- `KiriFriendsWatchApp` — watchOS app shell.
- `KiriFriendsBridge` — iPhone companion support code.
- `KiriFriendsCLI` — macOS bridge entry point.

## Commands

Run these commands from `apps/apple/`:

```bash
swift build
swift test
swift run KiriFriendsCLI
```

The watchOS and iOS app bundle targets will move to an Xcode workspace when signing, entitlements, WatchConnectivity, notifications, and WidgetKit extensions are added.
