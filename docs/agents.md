# Agent Path Index

Quick reference for agents working on the Kiri Friends codebase.

## Standard Operating Procedures

### Starting a New Feature

1. Read the relevant domain documentation in `docs/`.
2. Check `docs/roadmap/README.md` for milestone alignment.
3. Implement the feature with tests in `Tests/KiriFriendsCoreTests/`.
4. Update relevant `docs/` files in the same change set.

### Making UI Changes

1. Read `docs/product/information-architecture.md` for navigation model.
2. Read `docs/interfaces/watchos-swiftui-interface.md` for interface patterns.
3. Read `docs/standards/README.md` for implementation standards.
4. Follow the UI copy constraints in `AGENTS.md`.

### Changing the Communication Protocol

1. Read `docs/core/cli-bridge.md` for protocol specification.
2. Read `docs/server/relay-server.md` and `docs/server/api.md` for Cloud Relay behavior.
3. Update the protocol documentation before implementation.
4. Ensure `KiriFriendsCore` remains the source of truth.

### Changing CLI Integrations

1. Read `docs/core/cli-plugins.md` for plugin and hook contracts.
2. Read `docs/core/cli-adapters.md` for normalized adapter behavior.
3. Preserve user-owned Claude Code, Codex, and OpenCode configuration.
4. Add install and uninstall tests for config changes.

## Useful Commands

```bash
# Build all targets
make swift-build

# Run tests
make test

# Run watchOS app on simulator
make run-watch
```

## Architecture Decision Records

ADR documents are stored in `docs/decisions/` when architectural decisions need to be recorded.

Current ADRs:

- `docs/decisions/0001-watch-iphone-cloud-mac-topology.md`
