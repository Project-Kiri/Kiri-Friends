# Cloud Relay Server

The Cloud Relay server routes Kiri Friends messages between iPhone companions and CLI Host Bridges. It is the only cross-device message relay and enables remote request delivery without requiring inbound access to a user's computer.

## Responsibilities

The relay server owns:

- User and device authentication.
- Device pairing between iPhone companions and CLI Host Bridges.
- Presence for connected devices and active CLI sessions.
- Uplink event ingestion from CLI Host Bridges.
- Downlink request delivery to CLI Host Bridges.
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

A Kiri Friends account. A user can own multiple iPhone companions and CLI Host Bridges.

### Device

A registered client device.

Supported device roles:

- `iphone_companion`
- `cli_host_bridge`
- `mac_bridge` (legacy alias during migration)

The watch is represented through its paired iPhone companion, not as an independent relay client.

### Pairing

A trust binding between an iPhone companion and a CLI Host Bridge. Pairing should be explicit and revocable.

### Session

A normalized CLI session tracked by the CLI Host Bridge. Sessions can represent Claude Code, Codex, or OpenCode activity.

### Request

A user-originated action that must be delivered to a CLI Host Bridge. Examples include stop task, approve request, deny request, send quick prompt, and refresh status.

### Event

A CLI-host-originated status update sent to companion devices. Examples include task started, output preview, permission requested, task completed, and bridge offline.

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

CLI Host Bridge to relay:

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
- Active CLI Host selection changes.

Relay to CLI Host Bridge:

- Request envelopes with idempotency keys.
- Expiration timestamps.
- Reply channel metadata.

## Queueing and Expiration

Downlink requests are queued only when the target CLI Host Bridge is temporarily offline or reconnecting.

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
- `updatedAt`
- `expiresAt`
- `idempotencyKey`
- `payload`

The current HTTP implementation exposes device registration, pairing approval,
event ingest, event listing, request enqueue, pending request listing,
request acknowledgement/completion, heartbeat, and presence routes in
`server/src/http-server.ts`. Event ingest stores the full normalized plugin
envelope fields so the iPhone can fold multi-agent state from top-level
`tool` without depending on duplicated payload fields.

Expired requests are not delivered. The relay should emit an expiration event to the iPhone companion when the user needs feedback.

## Delivery Acknowledgement

Requests that affect CLI behavior require acknowledgement from the CLI Host Bridge.

Acknowledgement states:

- `accepted`: bridge received and will attempt the request.
- `completed`: bridge completed the request.
- `failed`: bridge could not complete the request.
- `expired`: request expired before completion.
- `superseded`: a newer request made this one irrelevant.

The relay should distinguish transport delivery from CLI completion. A request can be delivered but still fail at the adapter layer.

The bridge acknowledges delivery with `POST /v1/requests/:requestId/ack`.
`accepted` records transport receipt, while `completed` and `failed` record
the Mac bridge's execution result. Completion may include a structured result
object; failures may include an error string. Expired requests are not returned
from `/v1/requests/pending`.

## Debug CLI

Local relay testing uses an external debug CLI rather than unauthenticated
server routes. The CLI talks to the same HTTP API as real clients, so it creates
device tokens through registration, approves pairing through the iPhone role,
ingests plugin events through the Mac role, and queues requests through the
iPhone role.

Typical flow:

```sh
cd server
npm run debug -- seed --scenario approval-shell
```

The command prints `KIRI_RELAY_URL`, `KIRI_DEVICE_TOKEN`, `KIRI_USER_ID`, and
`KIRI_MAC_DEVICE_ID` values that can be copied into the iPhone companion's
relay configuration. Additional scenarios can be injected into the same relay:

```sh
npm run debug -- scenario waiting-input --mac-token <mac-token>
npm run debug -- request prompt.sendQuick --iphone-token <iphone-token> --mac-device-id <mac-device-id>
npm run debug -- ack <request-id> --mac-token <mac-token> --status completed
```

Supported scenarios live in `server/src/debug-scenarios.ts` and cover approval,
input waiting, running, failed, and multi-agent states. Because the debug CLI is
outside the server router, production deployments do not expose a debug bypass.

## Idempotency

Every mutating request must include an idempotency key. The relay and CLI Host Bridge should deduplicate repeated delivery attempts by `userId`, `targetDeviceId`, and `idempotencyKey`.

Idempotency keys prevent duplicated approvals, repeated prompts, and repeated stop commands after reconnection.

## Rate Limits

Rate limits protect users and relay infrastructure.

Recommended initial limits:

- Device registration: low frequency per account and IP.
- Event ingestion: burst-limited per CLI Host Bridge.
- Downlink requests: strict limits for watch-originated actions.
- Output previews: size-limited and frequency-limited.

When rate limits are hit, the relay should preserve safety-critical events such as permission requests and connection lost events while dropping low-priority output previews.

## Offline Behavior

When the iPhone companion is offline:

- The relay can retain recent high-priority Mac events for short replay.
- Normal output chunks should be dropped or compacted.
- The CLI Host Bridge should continue local CLI operation.

When the CLI Host Bridge is offline:

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
