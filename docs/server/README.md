# Server Documentation

The Kiri Friends server layer provides the Cloud Relay used to route requests between the iPhone companion and the user's Mac bridge when they are not on the same local network.

## Documents

- [relay-server.md](relay-server.md) — relay responsibilities, routing model, queues, retries, and presence.
- [api.md](api.md) — API contract for device registration, relay channels, event ingestion, request delivery, and acknowledgements.
- [deployment.md](deployment.md) — deployment shape, environment configuration, observability, data retention, and failure modes.

## Boundary

The Cloud Relay is not a CLI host and does not execute commands. It only authenticates devices, routes messages, queues downlinks, and records delivery status.

```text
iPhone Companion <-> Cloud Relay <-> Mac Bridge <-> CLI plugins and hooks
```

The Apple Watch communicates only with the iPhone companion through WatchConnectivity. The Cloud Relay never connects directly to the watchOS app.

## Design Principles

1. **Outbound Mac connectivity**: the Mac bridge opens an outbound connection to the relay. Users should not need inbound firewall or router configuration.
2. **Small payloads**: relay messages should contain normalized state and short previews, not full transcripts by default.
3. **Explicit delivery**: requests that affect CLI behavior require acknowledgements.
4. **Short retention**: relay data is operational and temporary unless a user-facing feature explicitly requires persistence.
5. **Privacy first**: sensitive command, prompt, and output fields must be redacted before reaching watch surfaces unless previews are enabled.
