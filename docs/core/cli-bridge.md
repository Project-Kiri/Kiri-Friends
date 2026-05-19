# CLIBridge Protocol

The CLIBridge protocol defines the local and remote message contract between the iPhone companion, Cloud Relay server, Mac bridge, and CLI adapters.

The Apple Watch does not speak CLIBridge directly. Watch-originated actions are translated by the iPhone companion into CLIBridge requests.

## Participants

| Participant | Role |
| --- | --- |
| iPhone companion | Converts watch and phone actions into relay requests; receives events for UI, notifications, and WatchConnectivity. |
| Cloud Relay server | Authenticates devices, routes messages, queues downlinks, and records delivery acknowledgement. |
| CLI Host Bridge | Maintains local CLI state, ingests plugin events, executes adapter-specific requests, and connects outbound to the Cloud Relay. |
| CLI adapter | Converts normalized Kiri requests into Claude Code, Codex, or OpenCode behavior. |

## Transport

Supported transports:

- iPhone companion to Cloud Relay: HTTPS plus a streaming channel.
- CLI Host Bridge to Cloud Relay: outbound HTTPS plus a streaming channel.
- Local plugin to CLI Host Bridge: Unix domain socket or localhost HTTP.
- Development fallback: local TCP socket on `127.0.0.1:7474`.
- Local Unix socket fallback: `~/.kirifriends/bridge.sock`.

### Cloud Relay HTTP Surface

The Cloud Relay server implements a thin HTTP layer over `RelayStore`
(see `server/src/http-server.ts`). All protected routes expect
`Authorization: Bearer <deviceToken>` and validate role.

| Route | Method | Caller | Notes |
| --- | --- | --- | --- |
| `/healthz` | GET | any | Liveness check (no auth) |
| `/v1/devices/iphone` | POST | iPhone companion | Registers an iPhone companion and returns a device token. |
| `/v1/devices/mac` | POST | Mac Buddy / CLI host bridge | Registers a Mac bridge and returns a device token plus pairing code. |
| `/v1/pairings/approve` | POST | iPhone companion | Approves a Mac pairing code for the authenticated user. |
| `/v1/plugin-events` | POST | Mac Buddy / CLI host bridge | Ingests `PluginEventEnvelope`. The relay preserves top-level `version`, `tool`, `event`, `sessionId`, `cwd`, `createdAt`, `sensitivity`, and `payload`. |
| `/v1/events` | GET | iPhone companion | Lists events for the calling user; supports `since=<eventId>` cursor. |
| `/v1/requests` | POST | iPhone companion | Enqueues a downlink request for the paired Mac. |
| `/v1/requests/pending` | GET | Mac Buddy / CLI host bridge | Returns queued requests for the calling device. |
| `/v1/requests/:requestId/ack` | POST | Mac Buddy / CLI host bridge | Moves a request to `accepted`, `completed`, `failed`, `expired`, or `superseded`; completion can include a result object or error string. |
| `/v1/heartbeat` | POST | any authenticated device | Updates the device's presence record. |
| `/v1/presence` | GET | any authenticated device | Lists presence records for the authenticated user's devices; accepts optional `deviceId`. |

Run the development server with `make dev-relay` (binds `127.0.0.1:8585`
by default; override with `KIRI_RELAY_HOST` / `KIRI_RELAY_PORT`).

The preferred production path is outbound-only from the CLI Host Bridge to the Cloud Relay. The Cloud Relay is the only cross-device message relay and should not require inbound access to a user's computer.

## Envelope

All messages use a versioned JSON envelope:

```json
{
  "version": 1,
  "id": "uuid-v4",
  "correlationId": "uuid-v4",
  "type": "request",
  "createdAt": "2026-05-17T12:00:00Z",
  "expiresAt": "2026-05-17T12:00:20Z",
  "source": {
    "role": "iphone_companion",
    "deviceId": "device-uuid"
  },
  "target": {
    "role": "cli_host_bridge",
    "deviceId": "device-uuid"
  },
  "payload": {}
}
```

### Fields

| Field | Required | Notes |
| --- | --- | --- |
| `version` | Yes | Protocol version. Breaking changes increment this value. |
| `id` | Yes | Unique message ID. |
| `correlationId` | No | Links responses and events to the originating request. |
| `type` | Yes | `request`, `response`, `event`, `ack`, or `heartbeat`. |
| `createdAt` | Yes | ISO 8601 timestamp. |
| `expiresAt` | Request only | Required for requests that affect CLI behavior. |
| `source` | Yes | Sender role and device ID. |
| `target` | No | Target role and device ID when known. |
| `payload` | Yes | Message-specific body. |

## Connection Lifecycle

### Handshake

Clients identify their role, device ID, app version, supported protocol versions, and supported capabilities.

```json
{
  "version": 1,
  "id": "handshake-uuid",
  "type": "request",
  "createdAt": "2026-05-17T12:00:00Z",
  "payload": {
    "action": "handshake",
    "role": "mac_bridge",
    "deviceId": "device-uuid",
    "supportedVersions": [1],
    "capabilities": ["events.uplink", "requests.downlink", "approvals"]
  }
}
```

### Heartbeat

Streaming clients send heartbeats at a fixed interval. Missing heartbeats move the device to `offline` presence.

```json
{
  "version": 1,
  "id": "heartbeat-uuid",
  "type": "heartbeat",
  "createdAt": "2026-05-17T12:00:10Z",
  "payload": {
    "presence": "busy",
    "activeSessionId": "session-uuid"
  }
}
```

### Reconnect

After reconnect, clients should send:

- Latest device capabilities.
- Latest known session summary.
- Last received event cursor when available.

The relay may replay recent high-priority events. Output chunks may be dropped or compacted.

## Request Types

### `status.refresh`

Get current normalized CLI status.

```json
{
  "version": 1,
  "id": "request-uuid",
  "type": "request",
  "createdAt": "2026-05-17T12:00:00Z",
  "idempotencyKey": "status-refresh-20260517T120000Z",
  "payload": {
    "action": "status.refresh"
  }
}
```

### `prompt.sendQuick`

Send a short prompt to the active CLI session.

```json
{
  "version": 1,
  "id": "request-uuid",
  "type": "request",
  "createdAt": "2026-05-17T12:00:00Z",
  "expiresAt": "2026-05-17T12:00:30Z",
  "idempotencyKey": "quick-reply-session-uuid",
  "payload": {
    "action": "prompt.sendQuick",
    "sessionId": "session-uuid",
    "text": "Explain this error"
  }
}
```

### `task.stop`

Stop the current running task for a specific session.

```json
{
  "version": 1,
  "id": "request-uuid",
  "type": "request",
  "createdAt": "2026-05-17T12:00:00Z",
  "expiresAt": "2026-05-17T12:00:15Z",
  "idempotencyKey": "stop-session-uuid",
  "payload": {
    "action": "task.stop",
    "sessionId": "session-uuid"
  }
}
```

### `voice.inputRequest` (Watch-originated)

Initiates speech recognition on the iPhone companion. The iPhone uses
`SFSpeechRecognizer` to transcribe speech from its own microphone, then
automatically forwards the result as a `prompt.sendQuick` action. This action
is never sent to the Cloud Relay; it is handled entirely within the iPhone
companion. After transcription, the iPhone echoes the recognized text back to
the watch via `voice.transcription` so the user can confirm what was understood.

### `approval.allow` / `approval.deny`

Approve or deny a CLI permission request.

```json
{
  "version": 1,
  "id": "request-uuid",
  "correlationId": "permission-event-uuid",
  "type": "request",
  "createdAt": "2026-05-17T12:00:00Z",
  "expiresAt": "2026-05-17T12:00:12Z",
  "idempotencyKey": "approval-approval-uuid-allow",
  "payload": {
    "action": "approval.allow",
    "sessionId": "session-uuid",
    "approvalId": "approval-uuid"
  }
}
```

## Response Format

Responses reuse the request `id` as `correlationId`.

```json
{
  "version": 1,
  "id": "response-uuid",
  "correlationId": "request-uuid",
  "type": "response",
  "createdAt": "2026-05-17T12:00:01Z",
  "payload": {
    "ok": true,
    "data": {},
    "error": null
  }
}
```

## Error Format

```json
{
  "ok": false,
  "data": null,
  "error": {
    "code": "target_offline",
    "message": "The selected Mac bridge is offline.",
    "retryable": true
  }
}
```

Error codes:

- `invalid_request`
- `schema_version_unsupported`
- `not_authenticated`
- `not_authorized`
- `target_offline`
- `session_not_found`
- `request_expired`
- `adapter_unsupported`
- `adapter_failed`
- `rate_limited`
- `payload_too_large`
- `internal_error`

## Event Types

CLI tools push events through the Mac bridge without a preceding request.

### `session.started`

```json
{
  "version": 1,
  "id": "event-uuid",
  "type": "event",
  "createdAt": "2026-05-17T12:00:00Z",
  "payload": {
    "event": "session.started",
    "sessionId": "session-uuid",
    "tool": "codex",
    "title": "Running tests"
  }
}
```

### `task.updated`

```json
{
  "version": 1,
  "id": "event-uuid",
  "type": "event",
  "createdAt": "2026-05-17T12:00:05Z",
  "payload": {
    "event": "task.updated",
    "sessionId": "session-uuid",
    "state": "running",
    "summary": "Editing documentation"
  }
}
```

### `approval.requested`

```json
{
  "version": 1,
  "id": "event-uuid",
  "type": "event",
  "createdAt": "2026-05-17T12:00:10Z",
  "payload": {
    "event": "approval.requested",
    "sessionId": "session-uuid",
    "approvalId": "approval-uuid",
    "tool": "codex",
    "title": "Approve shell command?",
    "summary": "Run unit tests",
    "sensitivity": "preview",
    "expiresAt": "2026-05-17T12:00:22Z"
  }
}
```

### `output.preview`

```json
{
  "version": 1,
  "id": "event-uuid",
  "type": "event",
  "createdAt": "2026-05-17T12:00:12Z",
  "payload": {
    "event": "output.preview",
    "sessionId": "session-uuid",
    "content": "3 tests failed",
    "sensitivity": "preview"
  }
}
```

### `task.completed`

```json
{
  "version": 1,
  "id": "event-uuid",
  "type": "event",
  "createdAt": "2026-05-17T12:01:00Z",
  "payload": {
    "event": "task.completed",
    "sessionId": "session-uuid",
    "result": "success"
  }
}
```

## Delivery Acknowledgement

Requests that can mutate CLI state require acknowledgements.

```json
{
  "version": 1,
  "id": "ack-uuid",
  "correlationId": "request-uuid",
  "type": "ack",
  "createdAt": "2026-05-17T12:00:02Z",
  "payload": {
    "status": "accepted"
  }
}
```

Acknowledgement statuses:

- `accepted`
- `completed`
- `failed`
- `expired`
- `superseded`

## Sensitivity

Payloads with user-visible text should include `sensitivity`.

| Value | Behavior |
| --- | --- |
| `none` | Safe operational metadata. |
| `preview` | Short text preview can be shown in app UI when previews are enabled. |
| `private` | Do not show on watch face, notifications, or Always On. |
| `secret` | Do not send to the relay. Keep on device. |

## Compatibility

Version 1 should remain stable through the first implementation milestone. Breaking changes require a new protocol version and an explicit migration note.
