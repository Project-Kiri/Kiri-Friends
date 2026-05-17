# Reference Project Research

This document summarizes the reference code under `.workspace/reference/` and records which patterns Kiri Friends should adopt, adapt, or avoid.

## Scope

The current reference workspace contains two relevant projects:

- `.workspace/reference/petdex/`
- `.workspace/reference/codex-buddy-bridge/`

The goal is not to copy either project. The goal is to extract proven patterns for CLI hook integration, local bridge behavior, failure handling, and user configuration safety.

## petdex

`petdex` is the strongest reference for multi-agent configuration and lifecycle event normalization.

Relevant files:

- `.workspace/reference/petdex/packages/petdex-cli/src/hooks/agents.ts`
- `.workspace/reference/petdex/packages/petdex-cli/src/hooks/install.ts`
- `.workspace/reference/petdex/packages/petdex-cli/src/hooks/uninstall.ts`
- `.workspace/reference/petdex/packages/petdex-desktop/README.md`

### Patterns to Adopt

- Maintain a single agent registry that describes each supported CLI by ID, display name, configuration paths, hook entries, docs URL, and post-install checks.
- Normalize different CLI lifecycle events into a smaller internal event vocabulary before sending them to the rest of the system.
- Treat OpenCode differently from JSON-config agents because OpenCode uses plugin files.
- Detect installed agents before writing configuration.
- Create backups before changing user-owned agent configuration.
- Remove only Kiri Friends-owned hook entries on uninstall.
- Keep post-install checks best-effort and agent-specific. For example, Codex needs hook feature flags before it loads hooks.

### Patterns to Adapt

`petdex` sends hook updates to a local HTTP sidecar. Kiri Friends should adapt this into a Mac bridge process that can:

- Accept plugin and hook events from local CLIs.
- Maintain normalized session state.
- Connect to the Cloud Relay server for remote request delivery.
- Preserve a local-only fallback path for development and degraded operation.

`petdex` maps events directly to pet animation states. Kiri Friends should map events to domain states such as `idle`, `running`, `waitingForApproval`, `needsAttention`, `failed`, and `completed`.

### Patterns to Avoid

- Do not couple product state directly to mascot animation states.
- Do not assume every CLI has the same hook mechanism.
- Do not expose implementation URLs or tokens in success messages intended for normal users.

## codex-buddy-bridge

`codex-buddy-bridge` is the strongest reference for permission request handling, Unix socket IPC, and fail-open behavior.

Relevant files:

- `.workspace/reference/codex-buddy-bridge/README.en.md`
- `.workspace/reference/codex-buddy-bridge/codex_buddy_bridge/ipc.py`
- `.workspace/reference/codex-buddy-bridge/hooks/permission_request.py`
- `.workspace/reference/codex-buddy-bridge/launchd/com.claudecodebuddy.codex-buddy.plist.template`

### Patterns to Adopt

- Hook scripts read JSON from stdin and write only the CLI-required response JSON to stdout.
- Diagnostics go to stderr so stdout remains parseable by the host CLI.
- Hook clients use a simple newline-delimited JSON protocol to a local daemon.
- The local daemon owns long-lived state and external transport concerns.
- Hook timeouts are shorter than the host CLI hook timeout.
- When the daemon is unreachable or the downstream device is unavailable, the hook declines to decide so the host CLI can fall back to its native flow.
- Unix domain sockets should use restrictive permissions.
- The daemon should be manageable through normal platform lifecycle tooling on macOS.

### Patterns to Adapt

`codex-buddy-bridge` sends approval requests to BLE hardware. Kiri Friends should send equivalent approval and action requests through:

1. CLI hook or plugin.
2. Local Mac bridge.
3. Cloud Relay server.
4. iPhone companion app.
5. Apple Watch app and notifications.

The approval timeout budget must account for every hop. The Mac bridge should degrade before the CLI hook deadline, not after.

### Patterns to Avoid

- Do not require the Apple Watch path to be available for a CLI action to continue.
- Do not block a CLI indefinitely while waiting for a watch response.
- Do not put private prompt or tool input text on watch faces unless the user explicitly enables previews.

## Kiri Friends Implications

Kiri Friends should use a layered communication model:

```text
CLI hook or plugin
  -> Mac bridge
  -> Cloud Relay server
  -> iPhone companion
  -> Watch app
```

Each layer should have a bounded responsibility:

- CLI plugins and hooks collect events and return decisions to the host CLI.
- The Mac bridge normalizes events, owns local session state, and connects to the Cloud Relay.
- The Cloud Relay authenticates devices, routes requests, queues downlinks, and records delivery acknowledgements.
- The iPhone companion owns user settings, local caching, push notification integration, and WatchConnectivity.
- The watchOS app owns glanceable status, quick actions, complications, and actionable notifications.

## Open Questions for Implementation

- Which Cloud Relay transport should be primary for Mac bridge downlinks: WebSocket, Server-Sent Events, or HTTPS long polling?
- Which events should be end-to-end encrypted versus protected only by TLS and server-side access controls?
- What is the maximum watch approval timeout that still feels useful without causing CLI hook failures?
- How much CLI output history should the relay retain, if any?

These questions should be resolved in the architecture decision records and server specifications before implementation.
