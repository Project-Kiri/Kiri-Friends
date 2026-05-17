# Kiri Friends Cloud Relay

This TypeScript workspace contains the Cloud Relay server core.

Initial scope:

- Device registration for iPhone companions and Mac bridges.
- Pairing code approval.
- Scoped device tokens.
- Heartbeat-based presence.
- In-memory request queue and delivery acknowledgement.

## Commands

```bash
npm install
npm test
npm run typecheck
```

The first implementation keeps storage in memory so API behavior can be tested before choosing durable and ephemeral backends.
