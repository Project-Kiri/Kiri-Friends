# Testing and Quality

Kiri Friends should be tested at protocol boundaries first. The product spans watchOS, iPhone, a Cloud Relay, a Mac bridge, and CLI plugins, so reliable contracts matter more than broad UI automation in the early milestones.

## Test Pyramid

1. Core domain and protocol unit tests.
2. Adapter and plugin contract tests.
3. Relay API and queue behavior tests.
4. WatchConnectivity serialization tests.
5. Buddy presentation, asset manifest, and health summary reducer tests.
6. Focused watchOS UI previews and manual QA.
7. End-to-end smoke tests with one CLI at a time.

## Core Tests

Location:

- `Tests/KiriFriendsCoreTests/`

Coverage:

- Domain model encoding and decoding.
- CLIBridge envelope validation.
- Error payload parsing.
- Sensitivity classification.
- State transition reducers.
- Idempotency key behavior.
- Buddy presentation reducers.
- Asset manifest validation.
- Low-sensitivity HealthKit summary classification.

Recommended test style:

- Use golden JSON fixtures for protocol compatibility.
- Test unknown enum values where forward compatibility matters.
- Keep Core platform-independent.

## CLI Plugin Tests

Coverage:

- Hook stdin parsing.
- Stdout purity for hooks that return host CLI decisions.
- Stderr diagnostics.
- Timeout behavior.
- Bridge unavailable fallback.
- Redaction before forwarding payloads.
- Codex `PermissionRequest` decline-to-decide behavior.
- OpenCode config path resolution.
- Claude hook event mapping.

Plugins must not make host CLIs hang when Kiri Friends is unavailable.

## Adapter Tests

Coverage:

- Tool-specific event to normalized event mapping.
- Tool-specific state to normalized state mapping.
- Capability reporting.
- Unsupported command errors.
- Install merge behavior.
- Uninstall preservation of user-owned config.
- Backup creation before config writes.

Every adapter should have tests proving that unrelated user configuration survives install and uninstall.

## Cloud Relay Tests

Coverage:

- Device registration.
- Pairing approval and expiration.
- Token scope by role.
- Presence timeout.
- Request enqueue.
- Downlink delivery.
- Delivery acknowledgement.
- Request expiration.
- Idempotent duplicate request handling.
- Rate limit responses.
- Payload size and sensitivity rejection.

Relay tests should distinguish delivery success from CLI completion success.

The server package includes an external debug CLI for manual relay testing. It
must remain a client of the authenticated HTTP API, not a debug route inside the
server. Use it to seed end-to-end hook states before exercising iPhone and Watch
UI:

```sh
cd server
npm run debug -- seed --scenario approval-shell
npm run debug -- seed --scenario waiting-input
```

The seeded environment should be enough to verify relay event folding,
WatchConnectivity snapshot delivery, hook-only action buttons, and downlink
request acknowledgement without installing real CLI hooks.

## WatchConnectivity Tests

Coverage:

- Snapshot payload encoding into property-list-compatible values.
- Watch action payload validation.
- Queued event deduplication.
- Offline cache behavior.
- Redaction rules for watch payloads.
- Buddy asset transfer metadata validation.

When simulator automation is available, test both iPhone to Watch and Watch to iPhone message paths.

## Widget and Notification Tests

Coverage:

- Widget timeline entry construction.
- App Group snapshot reading and writing.
- Supported complication family rendering in previews.
- Notification category registration.
- Notification action routing.
- Expired approval action handling.
- Privacy behavior for Short Look and Long Look content.
- Health context opt-in behavior separate from local buddy reactions.

## Manual QA Checklist

### Watch App

- [ ] App launches without crash.
- [ ] Status, Sessions, Commands, and Settings tabs are accessible.
- [ ] Primary state is understandable within 2 seconds.
- [ ] Offline state is visible and actions are disabled when needed.
- [ ] Approval action can be completed from the watch.
- [ ] During an approval hook, Status and Commands show only `Approve` and
      `Deny`; turning the wrist switches the highlighted option once per
      deliberate turn.
- [ ] During an input hook, `Reply` is highlighted and Apple Watch Double Tap
      sends the quick reply action.
- [ ] With no hook pending, Status and Commands show no interactive action
      buttons and wrist motion does not change selection.
- [ ] Expired approval action fails safely.

### Watch Buddy Art

- [ ] Status tab renders the active theme's buddy art (Clawd pixel
      crab by default), not an SF Symbol.
- [ ] Buddy breathes (subtle scale animation) when Reduce Motion is
      off, and holds still when Reduce Motion is on.
- [ ] Switching themes on iPhone (Settings → Buddy → Theme) updates
      the watch within ~1 second over Watch Connectivity.
- [ ] Watch Settings tab shows the active theme display name.
- [ ] All four state buckets (idle / running / attention / failed)
      render a distinct theme asset.
- [ ] `make verify-watch-assets` passes (Watch and Mac Buddy assets
      have not drifted).

### iPhone Companion

- [ ] iPhone can pair with a Mac bridge.
- [ ] Relay status is visible.
- [ ] Notification settings are discoverable.
- [ ] WatchConnectivity sync sends latest state to watch.
- [ ] Last-known state remains available offline.

### Mac Bridge

- [ ] Bridge can register with Cloud Relay.
- [ ] Bridge reconnects after network interruption.
- [ ] Bridge reports adapter capabilities.
- [ ] Bridge records local state when relay is unavailable.

### CLI Integrations

- [ ] Claude Code hooks emit lifecycle events.
- [ ] Codex `PermissionRequest` can be approved or denied.
- [ ] Codex falls back to native approval when Kiri is unavailable.
- [ ] OpenCode plugin emits lifecycle events.
- [ ] Uninstall preserves unrelated user configuration.

### Server

- [ ] Pairing codes expire.
- [ ] Offline Mac requests expire or queue according to policy.
- [ ] Duplicate requests are deduplicated.
- [ ] Delivery acknowledgement updates request status.
- [ ] Request completion records a result or error separate from delivery acknowledgement.
- [ ] Rate limits return machine-readable errors.

## Verification Commands

Use repository make targets when available:

```bash
make swift-build
make test
make test-apple
make test-plugins
make test-server
make verify-watch-assets
```

Current workspace commands:

```bash
cd apps/apple && swift test
cd server && npm test
cd server && npm run typecheck
cd plugins && npm test
cd plugins && npm run typecheck
```

## Release Quality Bar

Before a milestone is considered complete:

- Protocol docs match implemented payloads.
- Core golden fixtures pass.
- Adapter install and uninstall tests pass.
- Relay request expiration behavior is tested.
- Watch privacy checks pass for complications and notifications.
- Health context opt-in is tested separately from local buddy reactions.
- Manual QA has been run on paired simulators or real devices.
