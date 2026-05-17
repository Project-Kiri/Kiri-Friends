<p align="center">
  <strong>Kiri Friends</strong>
</p>

<p align="center">
  <strong>Your CLI tools, now on your wrist.</strong>
</p>

<p align="center">
  A bidirectional watchOS companion for Claude / OpenCode / Codex CLI.
</p>

<p align="center">
  <a href="https://www.swift.org">
    <img alt="Swift 6.0" src="https://img.shields.io/badge/Swift-6.0-F05138?logo=swift&logoColor=white">
  </a>
  <a href="https://developer.apple.com/watchos/">
    <img alt="watchOS 11+" src="https://img.shields.io/badge/watchOS-11%2B-000000?logo=apple&logoColor=white">
  </a>
  <a href="https://developer.apple.com/xcode/">
    <img alt="Xcode 16+" src="https://img.shields.io/badge/Xcode-16%2B-147EFB?logo=xcode&logoColor=white">
  </a>
  <img alt="Status: active development" src="https://img.shields.io/badge/status-active%20development-2563EB">
</p>

<p align="center">
  <a href="#features">Features</a> .
  <a href="#quick-start">Quick Start</a> .
  <a href="#architecture">Architecture</a> .
  <a href="#documentation">Docs</a> .
  <a href="#roadmap">Roadmap</a>
</p>

---

## Overview

Kiri Friends is an Apple Watch companion that brings your CLI AI tools to your wrist. It answers four questions at a glance:

- Which CLI tool is active?
- What is the current task or conversation status?
- Are there notifications or alerts from your CLI session?
- Can I send a quick command or prompt without pulling out my phone?

Daily actions stay on your wrist. Advanced features remain discoverable through the iPhone companion app when needed.

## Features

| Area | What Kiri Friends provides |
| --- | --- |
| Native watchOS app | SwiftUI interface built for Apple Watch with complications, notifications, and native controls. |
| Bidirectional communication | View CLI status on your wrist and send quick commands or prompts back to your tools. |
| iPhone companion | Bridge app that manages watch sync, notifications, and relay connection state. |
| Cloud Relay | Remote relay for device pairing, presence, request routing, and downlink delivery to the Mac bridge. |
| Multi-CLI support | Works with Claude Code, OpenCode, and Codex CLI through a unified protocol. |
| Complications | Watch face complications show active CLI status at a glance. |
| Conversation history | Browse recent CLI interactions and responses directly on your watch. |

## Screenshots

The v1 SwiftUI layout is being finalized. The current interface structure is documented in [docs/interfaces/watchos-swiftui-interface.md](docs/interfaces/watchos-swiftui-interface.md).

## Quick Start

### Requirements

- watchOS 11 or later
- iOS 18 or later (for iPhone companion)
- Xcode 16+ with the Swift 6.0 toolchain
- A paired Apple Watch for testing

### Build From Source

```bash
git clone https://github.com/your-org/kiri-friends.git
cd kiri-friends

# Build all targets
make swift-build

# Run watchOS app on simulator
make run-watch

# Or run tests
make test
```

## Architecture

```text
Watch App          iPhone Companion          Cloud Relay          Mac Host
    |                     |                       |                  |
    | WatchConnectivity   | HTTPS / WebSocket     | Downlink queue   |
    | WCSession           | Relay API             | CLIBridge        |
    v                     v                       v                  v
+-----------+       +---------------+       +--------------+    +-------------+
| watchOS   |       | iOS Bridge    |       | Kiri Relay   |    | Mac Bridge  |
| SwiftUI   | <---> | Notifications | <---> | Server       |<-->| CLI Plugins |
+-----------+       +---------------+       +--------------+    +-------------+
                                                                    |
                                                                    v
                                                           Claude / OpenCode / Codex
```

### Repository Layout

```text
apps/apple/                SwiftPM workspace for Apple clients and Mac bridge
  Sources/
    KiriFriendsWatchApp/   watchOS SwiftUI app shell
    KiriFriendsWatchKit/   Shared watch components and extensions
    KiriFriendsCore/       Shared domain models and protocol types
    KiriFriendsBridge/     iPhone companion support code
    KiriFriendsCLI/        Mac bridge entry point
server/                    TypeScript Cloud Relay
plugins/                   TypeScript CLI integrations
fixtures/                  Shared golden JSON contracts
```

## Documentation

| Domain | Description |
|--------|-------------|
| [Product](docs/product/README.md) | Product scope, daily workflow, and information architecture. |
| [Interfaces](docs/interfaces/README.md) | watchOS SwiftUI UI, complications, notifications, and iPhone companion surfaces. |
| [Core](docs/core/README.md) | Shared domain, CLIBridge protocol, state management, and CLI communication. |
| [Server](docs/server/README.md) | Cloud Relay routing, API contracts, deployment, and operational behavior. |
| [Operations](docs/operations/README.md) | App bundle integration, TestFlight distribution, and release management. |
| [Quality](docs/quality/README.md) | Testing strategy, verification commands, and manual QA checklist. |
| [Roadmap](docs/roadmap/README.md) | Feature roadmap and milestone tracking. |
| [Standards](docs/standards/README.md) | Implementation standards for watchOS UI and communication patterns. |
| [Decisions](docs/decisions/README.md) | Architecture decisions and topology rationale. |
| [Research](docs/research/README.md) | Reference project findings that inform Kiri Friends design. |

## Development

### Common Make Targets

| Command | Description |
|---------|-------------|
| `make swift-build` | Build Apple Swift targets |
| `make run-watch` | Build and run watchOS app on simulator |
| `make test` | Run Apple, server, and plugin tests |
| `make test-apple` | Run Swift tests in `apps/apple/` |
| `make test-server` | Run Cloud Relay tests in `server/` |
| `make test-plugins` | Run CLI plugin tests in `plugins/` |
| `make clean` | Clean build artifacts |

### Agent Contract

When communicating with CLI tools, Kiri Friends uses a JSON envelope:

```json
{
  "ok": true,
  "data": { ... },
  "error": null
}
```

See [docs/core/cli-bridge.md](docs/core/cli-bridge.md) for the full protocol specification.

## Roadmap

See [docs/roadmap/README.md](docs/roadmap/README.md) for the full roadmap.

## Contributing

1. Read [AGENTS.md](AGENTS.md) before making changes.
2. Update relevant `docs/` files in the same change set as implementation.
3. Follow the [docs/standards/README.md](docs/standards/README.md) guidelines.
4. Add tests for new domain behavior in `Tests/KiriFriendsCoreTests/`.

## License

MIT License. See [LICENSE](LICENSE) for details.
