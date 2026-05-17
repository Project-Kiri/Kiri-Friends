# Security and Privacy

Kiri Friends moves CLI state from a Mac to an iPhone and Apple Watch through a Cloud Relay. The system must minimize sensitive data, preserve native CLI safety flows, and make remote actions explicit.

## Trust Boundaries

```text
CLI process
  -> CLI plugin or hook
  -> Mac bridge
  -> Cloud Relay
  -> iPhone companion
  -> Apple Watch
```

Each boundary can reduce data. Later boundaries should receive less sensitive data than earlier boundaries.

## Data Classification

| Classification | Examples | Allowed Destinations |
| --- | --- | --- |
| `none` | Tool ID, state enum, timestamps | All layers |
| `preview` | Short task summary, sanitized status | Relay, iPhone, Watch app, notifications when enabled |
| `private` | Full prompt text, full command text, full paths | Mac bridge and iPhone app only when user enables previews |
| `secret` | Tokens, credentials, env vars, private keys | Must remain on Mac and must not be logged |

Plugins and adapters should classify payload fields before forwarding them.

## Authentication

### Device Tokens

Device tokens should be scoped to:

- User ID.
- Device ID.
- Device role.
- Token creation time.
- Token expiration or rotation policy.

Revoking a device must invalidate future relay access for that device.

### Pairing

Mac bridge pairing should require explicit approval from the user's signed-in iPhone companion.

Pairing codes should:

- Be short-lived.
- Be single-use.
- Show the Mac device name before approval.
- Be revocable.

## Authorization

The relay must verify:

- The source device belongs to the authenticated user.
- The target device is paired to the same user.
- The source role is allowed to send the requested message type.
- The target adapter supports the requested command.

Watch-originated actions arrive through the iPhone companion and inherit companion authorization. The watch should not receive relay credentials.

## Transport Security

- Public relay traffic uses TLS.
- Mac bridge connections are outbound-only.
- Local Unix sockets should use restrictive filesystem permissions.
- Localhost HTTP should bind only to `127.0.0.1`.
- Local plugin calls should use short timeouts and avoid exposing tokens in command-line arguments.

## Approval Safety

Approval requests can affect CLI behavior and require additional safeguards:

- Approval decisions must include `approvalId`, `sessionId`, `decision`, and expiration.
- Expired approval decisions must be rejected.
- Duplicate approval decisions must be deduplicated by idempotency key.
- If the watch path is unavailable, host CLIs should fall back to native approval UI.
- The Apple Watch should show only a concise summary by default.
- Full command text should require opening the iPhone companion or enabling explicit previews.

## Watch Face and Always On Redaction

Complications, Smart Stack widgets, and Always On states should never show private content by default.

Allowed by default:

- Tool icon or name.
- Status dot.
- Task state.
- Relative time.
- Generic action-required label.

Not allowed by default:

- Prompt text.
- Shell command text.
- File paths.
- Output snippets.
- Error details that may contain project secrets.

## Logging

Logs may include:

- Message IDs.
- Device IDs when needed for debugging.
- Event types.
- Adapter names.
- Error codes.
- Latency and retry counts.

Logs must not include:

- Raw prompts.
- Full command arguments.
- Tokens.
- Environment variables.
- Full CLI output.
- Secret file paths.

## Data Retention

Default retention policy:

- Relay queued requests: until completion or expiration.
- Delivery records: short operational window.
- Presence state: minutes.
- Device and pairing records: until revoked.
- Raw CLI content: not retained by default.

If future features require transcript sync, they must introduce a separate opt-in retention decision.

## User Controls

Users should be able to:

- Revoke a Mac bridge pairing.
- Disable watch notifications.
- Disable text previews on Apple Watch.
- Disable relay sync and use local-only development mode when supported.
- Uninstall CLI hooks without destroying unrelated CLI configuration.
- Rotate or revoke device tokens.

## Security Review Checklist

- [ ] No `secret` fields cross the Mac bridge boundary.
- [ ] Pairing codes expire and are single-use.
- [ ] Device tokens are scoped by role.
- [ ] Approval decisions expire before CLI hook deadlines.
- [ ] Watch complications do not reveal private content.
- [ ] Logs redact prompts, commands, output, and credentials.
- [ ] Uninstall preserves user CLI configuration.
- [ ] Rate limits protect event ingestion and request enqueue APIs.
