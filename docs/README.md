# Kiri Friends Technical Documentation

Kiri Friends is a bidirectional watchOS companion for Claude / OpenCode / Codex CLI. The first version focuses on a glanceable daily-use interface on Apple Watch, an iPhone companion bridge, and a shared communication protocol with CLI tools.

## Domain Map

- [Product](product/README.md) — product scope, daily workflow, and information architecture.
- [Interfaces](interfaces/README.md) — watchOS SwiftUI UI, complications, notifications, and iPhone companion surfaces.
- [Core](core/README.md) — shared domain, CLIBridge protocol, state management, and CLI communication.
- [Server](server/README.md) — Cloud Relay routing, API shape, deployment, and operational behavior.
- [Operations](operations/README.md) — app bundle integration, TestFlight distribution, and release management.
- [Quality](quality/README.md) — testing strategy, verification commands, and manual QA checklist.
- [Roadmap](roadmap/README.md) — feature roadmap and milestone tracking.
- [Implementation Standards](standards/README.md) — focused implementation standards for watchOS UI and communication patterns.
- [Architecture Decisions](decisions/README.md) — accepted topology and major design decisions.
- [Research](research/README.md) — reference project notes that inform Kiri Friends design.

## Current Source Layout

```text
apps/apple/
  Package.swift                SwiftPM workspace for Apple clients and Mac Buddy
  Sources/
    KiriFriendsCore/           Shared domain models, protocol definitions, state management
    KiriFriendsWatchKit/       Shared watch components and SwiftUI extensions
    KiriFriendsPhoneApp/       iPhone companion app shell
    KiriFriendsWatchApp/       watchOS SwiftUI buddy app shell
    KiriFriendsWidgets/        WidgetKit complications and Smart Stack surfaces
    KiriFriendsBridge/         iPhone companion support code
    KiriFriendsCLI/            Legacy CLI scaffold (placeholder; the Mac side now lives in Mac Buddy)
    KiriFriendsMacBuddyKit/    Mac Buddy domain library (AGPL-3.0)
    KiriFriendsBuddyMac/       Mac Buddy SwiftUI executable + bundled themes (AGPL-3.0)
  Tests/
    KiriFriendsCoreTests/      Unit tests for shared domain
    KiriFriendsMacBuddyKitTests/ Unit tests for the Mac Buddy state machine, HTTP bridge, theme loader, permission service
server/                        TypeScript Cloud Relay
plugins/                       TypeScript CLI plugins for the twelve supported hosts
fixtures/                      Shared golden JSON contracts
```

## Architectural Principle

The watchOS app, iPhone companion, Cloud Relay, CLI Host Bridge, and CLI plugins must share the same domain behavior. All surfaces should call `KiriFriendsCore` or use its documented protocol contracts rather than reimplementing communication protocol, state management, or CLI interaction logic. The Cloud Relay is the only cross-device message relay; the CLI Host Bridge only adapts local CLI hooks and maintains the outbound relay connection.
