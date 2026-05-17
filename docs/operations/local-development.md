# Local Development

Kiri Friends is a monorepo with three implementation workstreams:

- `apps/apple/` — SwiftPM workspace for Apple clients and Mac bridge.
- `server/` — TypeScript Cloud Relay.
- `plugins/` — TypeScript CLI plugins and installer helpers.

Do not run long-lived dev servers by default. Start only the short-lived build or test command needed for the current change.

## Commands

From the repository root:

```bash
make swift-build
make test-apple
make test-server
make test-plugins
```

From each workspace:

```bash
cd apps/apple && swift test
cd server && npm test
cd plugins && npm test
```

## End-to-End Slice Order

1. Validate shared fixtures in `fixtures/`.
2. Send a Codex `approval.requested` plugin event to the Mac bridge local endpoint.
3. Have the Mac bridge normalize the event and forward it to the Cloud Relay.
4. Have the Cloud Relay deliver the request to the iPhone companion channel.
5. Have the iPhone companion update watchOS through WatchConnectivity.
6. Send a watch approval action back through the iPhone companion and relay.
7. Have the Mac bridge acknowledge the decision and return the host-specific Codex response.

Each step should be testable independently before joining the full chain.
