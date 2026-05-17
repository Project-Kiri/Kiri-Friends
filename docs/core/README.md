# Core Documentation

Shared domain, CLIBridge protocol, state management, and CLI communication.

## Documents

- [cli-bridge.md](cli-bridge.md) — iPhone-to-CLI communication protocol specification.
- [cli-plugins.md](cli-plugins.md) — Claude Code, Codex, and OpenCode plugin and hook contracts.
- [cli-adapters.md](cli-adapters.md) — adapter model for normalizing tool-specific events and commands.
- [security-and-privacy.md](security-and-privacy.md) — trust boundaries, redaction, pairing, and approval safety.

## Core Principles

1. **Single Source of Truth**: `KiriFriendsCore` owns all domain models and protocol definitions.
2. **Platform Agnostic**: Core has no watchOS, iOS, server, or macOS dependencies.
3. **Protocol Driven**: All communication uses typed, versioned JSON envelopes.
4. **Immutable State**: Domain models are value types with clear mutation boundaries.
