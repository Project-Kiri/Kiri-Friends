# Cloud Relay Server

The Cloud Relay server routes Kiri Friends messages between iPhone companions and Mac bridges. It enables remote request delivery when the iPhone and Mac are not on the same local network.

## Responsibilities

The relay server owns:

- User and device authentication.
- Device pairing between iPhone companions and Mac bridges.
- Presence for connected devices and active CLI sessions.
- Uplink event ingestion from Mac bridges.
- Downlink request delivery to Mac bridges.
- Queueing while a target device is temporarily offline.
- Delivery acknowledgement, retry, expiration, and idempotency.
- Rate limits and payload size limits.

The relay server does not own:

- CLI execution.
- WatchConnectivity.
- Long-term conversation history by default.
- CLI plugin installation.
- User-facing notification permissions.

## Entities

### User

A Kiri Friends account. A user can own multiple iPhone companions and Mac bridges.

### Device

A registered client device.

Supported device roles:

- `iphone_companion`
- `mac_bridge`

The watch is represented through its paired iPhone companion, not as an independent relay client.

### Pairing

A trust binding between an iPhone companion and a Mac bridge. Pairing should be explicit and revocable.

### Session

A normalized CLI session tracked by the Mac bridge. Sessions can represent Claude Code, Codex, or OpenCode activity.

### Request

A user-originated action that must be delivered to a Mac bridge. Examples include stop task, approve request, deny request, send quick prompt, and refresh status.

### Event

A Mac-originated status update sent to companion devices. Examples include task started, output preview, permission requested, task completed, and bridge offline.

## Presence Model

Presence should be best-effort and short-lived.

| Presence | Meaning |
| --- | --- |
| `online` | Device has an active relay connection. |
| `idle` | Device is connected but has no active CLI task. |
| `busy` | Device has an active CLI task. |
| `waiting` | Device has at least one action-required request. |
| `offline` | Device has no active connection or heartbeat expired. |

Presence is derived from authenticated connections, heartbeats, and recent events. It must not be treated as proof that a CLI action can be completed.

## Routing

### Uplink

Mac bridge to relay:

- Lifecycle events.
- Permission request snapshots.
- Command results.
- Delivery acknowledgements.
- Heartbeats.

Relay to iPhone companion:

- Latest normalized state.
- Action-required events.
- Notification candidates.
- Request completion events.

### Downlink

iPhone companion to relay:

- Quick commands.
- Approval or denial decisions.
- Refresh requests.
- Active Mac selection changes.

Relay to Mac bridge:

- Request envelopes with idempotency keys.
- Expiration timestamps.
- Reply channel metadata.

## Queueing and Expiration

Downlink requests are queued only when the target Mac bridge is temporarily offline or reconnecting.

Default behavior:

- Action requests expire quickly.
- Approval decisions expire before the host CLI hook timeout.
- Refresh requests can be dropped when superseded.
- Stop requests should be delivered if still relevant, but must include a session ID to avoid stopping the wrong task.

Each queued item must include:

- `requestId`
- `userId`
- `targetDeviceId`
- `sessionId` when session-scoped
- `kind`
- `createdAt`
- `expiresAt`
- `idempotencyKey`
- `payload`

Expired requests are not delivered. The relay should emit an expiration event to the iPhone companion when the user needs feedback.

## Delivery Acknowledgement

Requests that affect CLI behavior require acknowledgement from the Mac bridge.

Acknowledgement states:

- `accepted`: bridge received and will attempt the request.
- `completed`: bridge completed the request.
- `failed`: bridge could not complete the request.
- `expired`: request expired before completion.
- `superseded`: a newer request made this one irrelevant.

The relay should distinguish transport delivery from CLI completion. A request can be delivered but still fail at the adapter layer.

## Idempotency

Every mutating request must include an idempotency key. The relay and Mac bridge should deduplicate repeated delivery attempts by `userId`, `targetDeviceId`, and `idempotencyKey`.

Idempotency keys prevent duplicated approvals, repeated prompts, and repeated stop commands after reconnection.

## Rate Limits

Rate limits protect users and relay infrastructure.

Recommended initial limits:

- Device registration: low frequency per account and IP.
- Event ingestion: burst-limited per Mac bridge.
- Downlink requests: strict limits for watch-originated actions.
- Output previews: size-limited and frequency-limited.

When rate limits are hit, the relay should preserve safety-critical events such as permission requests and connection lost events while dropping low-priority output previews.

## Offline Behavior

When the iPhone companion is offline:

- The relay can retain recent high-priority Mac events for short replay.
- Normal output chunks should be dropped or compacted.
- The Mac bridge should continue local CLI operation.

When the Mac bridge is offline:

- The iPhone companion shows last-known state.
- Quick actions are disabled or queued only when safe.
- Approval requests cannot be satisfied remotely.

When the relay is unavailable:

- CLI hooks fall back to native CLI behavior.
- The iPhone companion shows relay unavailable state.
- The watch shows cached status with no remote action guarantee.

## Data Retention

The relay should retain only operational data by default:

- Device records until revoked.
- Pairing records until revoked.
- Presence state while active.
- Delivery records for a short debugging window.
- Request payloads until completion or expiration.

Full transcripts and raw tool input should not be retained unless a future feature explicitly requires it and the user opts in.
