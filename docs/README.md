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
  Package.swift            SwiftPM workspace for Apple clients and Mac bridge
  Sources/
    KiriFriendsCore/       Shared domain models, protocol definitions, state management
    KiriFriendsWatchKit/   Shared watch components and SwiftUI extensions
    KiriFriendsWatchApp/   watchOS SwiftUI app shell
    KiriFriendsBridge/     iPhone companion support code
    KiriFriendsCLI/        Mac bridge entry point
  Tests/
    KiriFriendsCoreTests/  Unit tests for shared domain
server/                    TypeScript Cloud Relay
plugins/                   TypeScript CLI plugins and installer helpers
fixtures/                  Shared golden JSON contracts
```

## Architectural Principle

The watchOS app, iPhone companion, Cloud Relay, Mac bridge, and CLI plugins must share the same domain behavior. All surfaces should call `KiriFriendsCore` or use its documented protocol contracts rather than reimplementing communication protocol, state management, or CLI interaction logic.
