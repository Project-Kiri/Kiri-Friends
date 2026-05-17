# Cloud Relay Deployment

This document records deployment expectations for the Kiri Friends Cloud Relay. It intentionally avoids framework-specific implementation details.

## Runtime Shape

The relay service needs:

- HTTPS API endpoints for registration, pairing, events, requests, and acknowledgements.
- A streaming channel for Mac bridges and iPhone companions.
- A short-lived request queue.
- A presence store.
- A durable device and pairing store.
- Structured logging and metrics.

## Environment Configuration

Expected configuration:

| Variable | Purpose |
| --- | --- |
| `KIRI_ENV` | Runtime environment name such as `development`, `staging`, or `production`. |
| `KIRI_PUBLIC_BASE_URL` | Public API base URL used in pairing links. |
| `KIRI_DATABASE_URL` | Durable device, user, and pairing storage. |
| `KIRI_QUEUE_URL` | Request queue or stream backend. |
| `KIRI_TOKEN_SIGNING_KEY` | Signing key for device tokens. |
| `KIRI_LOG_LEVEL` | Structured log verbosity. |
| `KIRI_RETENTION_DAYS` | Operational event retention window. |

Secrets must be provided by the hosting environment, not committed to the repository.

## Data Stores

### Durable Store

Stores:

- Users.
- Devices.
- Pairings.
- Revoked tokens.
- Minimal audit records.

### Ephemeral Store

Stores:

- Presence.
- Heartbeat timestamps.
- Short-lived request queues.
- Delivery status.

Ephemeral data can be rebuilt from reconnecting clients and should expire aggressively.

## Observability

The relay should emit structured events for:

- Device registration.
- Pairing approval and revocation.
- Streaming channel connect and disconnect.
- Request enqueue.
- Request delivery.
- Request acknowledgement.
- Request expiration.
- Rate limit rejection.
- Payload rejection.

Recommended metrics:

- Active Mac bridge connections.
- Active iPhone companion connections.
- Downlink queue depth.
- Downlink delivery latency.
- Request expiration count.
- Event ingestion rate.
- Error rate by code.

Logs must avoid raw prompt text, command arguments, credentials, and full CLI output.

## Failure Modes

### Relay API Unavailable

Expected behavior:

- Mac bridge keeps local CLI integration running.
- CLI hooks fall back to native CLI behavior.
- iPhone companion shows relay unavailable.
- Watch shows cached state and disables unsafe actions.

### Streaming Channel Interrupted

Expected behavior:

- Clients reconnect with exponential backoff.
- Mac bridge replays latest state after reconnect.
- Relay expires requests that exceed `expiresAt`.

### Queue Backend Unavailable

Expected behavior:

- Server rejects mutating request enqueue calls with a retryable error.
- Existing active streams may continue to deliver direct events if possible.
- Clients show degraded state rather than implying successful delivery.

### Database Unavailable

Expected behavior:

- Registration and pairing fail closed.
- Existing token validation may continue only if safely cached.
- New device trust decisions are not accepted.

## Retention

Default retention should be short:

- Presence: minutes.
- Queued requests: until completion or expiration.
- Delivery records: days, configurable.
- Device and pairing records: until revoked.

Raw CLI output should not be retained by default.

## Deployment Checklist

- [ ] TLS is enforced for all public endpoints.
- [ ] Device tokens are scoped by user, device, and role.
- [ ] Pairing codes expire quickly.
- [ ] Request payload size limits are enforced.
- [ ] Logs redact user content.
- [ ] Metrics cover queue latency and expirations.
- [ ] Rate limits are enabled before public testing.
- [ ] Token revocation is tested.
- [ ] Backups cover durable device and pairing data.
- [ ] A status page or operational channel exists for relay outages.
