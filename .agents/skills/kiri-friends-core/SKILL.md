---
name: kiri-friends-core
description: Kiri Friends project-specific conventions. Use when implementing watchOS UI, CLIBridge communication, domain models, or iPhone companion features. Triggers on tasks involving the Kiri Friends codebase.
license: MIT
metadata:
  author: kiri-friends
  version: "1.0.0"
---

# Kiri Friends Core Conventions

## Module Boundaries

### KiriFriendsCore

The shared domain layer. No platform dependencies.

- **Models**: `CLIStatus`, `CLITask`, `CLICommand`, `CLIBridgeMessage`
- **Protocol**: `CLIBridgeProtocol`, message serialization
- **State**: `AppState`, `ConnectionState` (value types)

### KiriFriendsWatchKit

Shared watch components. watchOS-only dependencies.

- **Views**: Reusable SwiftUI view components
- **Complications**: WidgetKit complication definitions
- **Extensions**: SwiftUI and WatchKit extensions

### KiriFriendsWatchApp

watchOS executable. Depends on Core and WatchKit.

- **Entry**: `KiriFriendsWatchApp.swift`
- **Views**: `ContentView`, `StatusView`, `CommandsView`, `HistoryView`, `SettingsView`
- **Notifications**: `NotificationController`

### KiriFriendsCLI

Mac CLI bridge executable. Depends on Core.

- **Server**: TCP/Unix socket server
- **Client**: CLI tool adapters for Claude Code, OpenCode, Codex

## Communication Protocol

All messages use the JSON envelope defined in `docs/core/cli-bridge.md`:

```swift
struct CLIBridgeMessage: Codable {
    let version: Int
    let id: UUID
    let type: MessageType
    let payload: Payload
}
```

## Data Model Conventions

- Use structs, not classes, for all domain models
- Make models `Codable`, `Hashable`, and `Sendable`
- Use `UUID` for all identifiers
- Timestamps use `ISO8601DateFormatter`

## State Management

- Use `@Observable` (Swift 6) for reference-type state containers
- Use `@State` and `@Binding` for view-local state
- Propagate changes through `ObservableObject` only when crossing module boundaries

## Naming Conventions

- Types: `PascalCase` (e.g., `CLIStatus`, `TaskResult`)
- Functions and properties: `camelCase` (e.g., `currentTask`, `sendPrompt`)
- Files match their primary type name
- Test files: `{TypeName}Tests.swift`
