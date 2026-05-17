# Cloud Relay API

This document defines the initial API shape for the Kiri Friends Cloud Relay. It is a product and protocol specification, not an implementation commitment to a specific framework.

## API Principles

- All requests use TLS.
- All mutating client requests include an idempotency key.
- All envelopes use stable IDs and ISO 8601 timestamps.
- Server responses include machine-readable error codes.
- Streaming channels carry small normalized events, not full transcripts by default.

## Authentication

Clients authenticate as registered devices owned by a user account.

Device roles:

- `iphone_companion`
- `mac_bridge`

The server should support token rotation and device revocation. Device tokens must be scoped to one user and one device role.

## Common Envelope

```json
{
  "version": 1,
  "id": "uuid-v4",
  "createdAt": "2026-05-17T12:00:00Z",
  "source": {
    "deviceId": "device-uuid",
    "role": "iphone_companion"
  },
  "kind": "request.enqueue",
  "payload": {}
}
```

## Error Shape

```json
{
  "ok": false,
  "error": {
    "code": "not_authenticated",
    "message": "Device token is missing or invalid.",
    "retryable": false
  }
}
```

Recommended error codes:

- `not_authenticated`
- `not_authorized`
- `device_not_found`
- `pairing_required`
- `target_offline`
- `request_expired`
- `rate_limited`
- `payload_too_large`
- `schema_version_unsupported`
- `internal_error`

## Device Registration

### Register iPhone Companion

`POST /v1/devices/iphone`

Registers an iPhone companion for the authenticated user.

Request:

```json
{
  "deviceName": "Steven's iPhone",
  "appVersion": "1.0.0",
  "platformVersion": "iOS 18"
}
```

Response:

```json
{
  "ok": true,
  "data": {
    "deviceId": "device-uuid",
    "deviceToken": "opaque-token"
  }
}
```

### Register Mac Bridge

`POST /v1/devices/mac`

Registers a Mac bridge. The response includes a pairing code or pairing URL that the iPhone companion can approve.

Request:

```json
{
  "deviceName": "Steven's MacBook Pro",
  "bridgeVersion": "1.0.0",
  "supportedTools": ["claude-code", "codex", "opencode"]
}
```

Response:

```json
{
  "ok": true,
  "data": {
    "deviceId": "device-uuid",
    "deviceToken": "opaque-token",
    "pairingCode": "123456",
    "pairingExpiresAt": "2026-05-17T12:05:00Z"
  }
}
```

## Pairing

### Approve Pairing

`POST /v1/pairings/approve`

Request:

```json
{
  "pairingCode": "123456",
  "macDeviceName": "Steven's MacBook Pro"
}
```

Response:

```json
{
  "ok": true,
  "data": {
    "pairingId": "pairing-uuid",
    "macDeviceId": "device-uuid"
  }
}
```

### Revoke Pairing

`DELETE /v1/pairings/{pairingId}`

Revokes a Mac bridge pairing and invalidates future routing to that device.

## Relay Channels

The primary streaming transport should be WebSocket unless implementation constraints require Server-Sent Events or HTTPS long polling.

### Mac Bridge Channel

`GET /v1/relay/mac`

Mac bridge uses this channel for:

- Heartbeats.
- Presence updates.
- Incoming downlink requests.
- Sending delivery acknowledgements.

### iPhone Companion Channel

`GET /v1/relay/iphone`

iPhone companion uses this channel for:

- Receiving session events.
- Receiving request completion events.
- Receiving presence updates.
- Refreshing latest state before syncing to the watch.

## Event Ingestion

`POST /v1/events`

Mac bridges send normalized events to the relay.

Request:

```json
{
  "idempotencyKey": "event-key",
  "sessionId": "session-uuid",
  "tool": "codex",
  "event": "permission_requested",
  "createdAt": "2026-05-17T12:00:00Z",
  "payload": {
    "title": "Approve shell command?",
    "summary": "Run tests",
    "sensitivity": "preview"
  }
}
```

Response:

```json
{
  "ok": true,
  "data": {
    "eventId": "event-uuid",
    "deliveredTo": ["device-uuid"]
  }
}
```

## Request Enqueue

`POST /v1/requests`

iPhone companions enqueue user actions for a Mac bridge.

Request:

```json
{
  "idempotencyKey": "request-key",
  "targetDeviceId": "mac-device-uuid",
  "sessionId": "session-uuid",
  "kind": "approval.decide",
  "expiresAt": "2026-05-17T12:00:20Z",
  "payload": {
    "decision": "allow",
    "reason": "Approved on Apple Watch"
  }
}
```

Response:

```json
{
  "ok": true,
  "data": {
    "requestId": "request-uuid",
    "status": "queued"
  }
}
```

## Delivery Acknowledgement

`POST /v1/requests/{requestId}/ack`

Mac bridges acknowledge delivery and completion.

Request:

```json
{
  "status": "completed",
  "completedAt": "2026-05-17T12:00:05Z",
  "result": {
    "ok": true
  }
}
```

Response:

```json
{
  "ok": true,
  "data": {
    "requestId": "request-uuid",
    "status": "completed"
  }
}
```

## Payload Sensitivity

Events and requests should classify text payloads:

| Sensitivity | Meaning |
| --- | --- |
| `none` | No user content. |
| `preview` | Short user-visible summary. |
| `private` | Should not be shown on watch faces or notifications. |
| `secret` | Must not be stored by the relay. |

The relay should reject `secret` fields in persisted request queues. If a secret is needed for local CLI behavior, it should remain on the Mac bridge.
