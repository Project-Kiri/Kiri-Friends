# Watch Connectivity

The iPhone companion communicates with the Apple Watch through WatchConnectivity. The watchOS app does not connect directly to the Cloud Relay or Mac bridge.

## Goals

- Keep the watch app glanceable and battery-friendly.
- Show last-known CLI state when the iPhone or relay is unavailable.
- Send quick actions from watchOS to the iPhone companion.
- Avoid sending private content to complications or Always On surfaces.

## Session Ownership

The iPhone companion owns:

- Cloud Relay authentication.
- Relay streaming connection.
- Notification permission and scheduling.
- WatchConnectivity session.
- Cached normalized state.

The watch app owns:

- UI rendering.
- Watch-originated quick actions.
- Complication and widget data reads.
- Local display cache.

## Transfer Methods

| WatchConnectivity Method | Kiri Friends Use |
| --- | --- |
| `updateApplicationContext` | Latest state snapshot and settings. |
| `sendMessage` | Real-time watch actions when iPhone is reachable. |
| `transferUserInfo` | Queued event summaries and history updates. |
| `transferFile` | Future large exports only; not part of v1. |
| `transferCurrentComplicationUserInfo` | Budget-limited complication updates from iPhone. |

## Payload Constraints

WatchConnectivity payloads must use property-list-compatible values. Domain models should be encoded into dictionaries, strings, numbers, booleans, arrays, and dates.

Payloads should be small. The iPhone companion should summarize and redact relay events before sending them to watchOS.

## Latest State Snapshot

Use `updateApplicationContext` for the latest normalized state. As of
the Mac Buddy sync work the application context is a multi-kind
envelope: each payload sits inside a slot keyed by its
`WatchPayloadKind` raw value (`state.snapshot`, `buddy.settings`). The
iPhone companion merges instead of replacing so different kinds do not
overwrite each other.

```json
{
  "state.snapshot": {
    "schemaVersion": 1,
    "kind": "state.snapshot",
    "updatedAt": "2026-05-17T12:00:00Z",
    "activeTool": "codex",
    "connectionState": "relayConnected",
    "session": {
      "id": "codex-1",
      "state": "waitingForApproval",
      "title": "Run tests",
      "summary": "Approval required",
      "sensitivity": "preview",
      "tool": "codex"
    },
    "sessions": [
      {
        "id": "codex-1",
        "state": "waitingForApproval",
        "title": "Run tests",
        "summary": "Approval required",
        "sensitivity": "preview",
        "tool": "codex"
      },
      {
        "id": "claude-1",
        "state": "running",
        "title": "Documentation tour",
        "summary": "Editing docs",
        "sensitivity": "none",
        "tool": "claude-code"
      }
    ]
  },
  "buddy.settings": {
    "kind": "buddy.settings",
    "activeManifestId": "com.kirifriends.bufo",
    "buddyName": "Bufo",
    "showsPreviewText": false,
    "sharesAgentHealthContext": false
  }
}
```

Watch-side dispatch lives in `WatchSessionStore.ingest(applicationContext:)`
which iterates over the envelope slots, decoding each into its concrete
type. Legacy single-payload contexts (a top-level `kind` field) decode
through the same path for backwards compatibility.

The watch caches `state.snapshot` for offline display. `buddy.settings`
controls preview visibility and the active manifest. New CLI tools added
to `CLITool` decode to `.unknown` when the watch build is older than the
iPhone build, preventing the snapshot from being dropped.

## Real-Time Actions

Use `sendMessage` when the watch and iPhone companion are reachable.

Supported actions:

- `status.refresh`
- `task.stop`
- `approval.allow`
- `approval.deny`
- `prompt.sendQuick`

Example payload:

```json
{
  "schemaVersion": 1,
  "kind": "watch.action",
  "action": "approval.allow",
  "sessionId": "session-uuid",
  "approvalId": "approval-uuid",
  "createdAt": "2026-05-17T12:00:00Z"
}
```

The iPhone companion translates this into a CLIBridge request through the Cloud Relay.

## Queued Updates

Use `transferUserInfo` for summaries that can arrive later:

- Completed task summaries.
- Recent history entries.
- Notification follow-up state.
- Low-priority output previews.
- Buddy settings and asset sync acknowledgements.
- Low-sensitivity health summaries when the user opts in to agent context.

Queued updates should include an event ID so the watch can deduplicate.

## Offline Behavior

When iPhone is unreachable:

- Watch shows cached state.
- Unsafe actions are disabled.
- Complications continue to show last-known status with relative time.

When relay is unavailable:

- iPhone sends `connectionState: relayUnavailable` to watch.
- Watch avoids implying actions can be delivered.

When Mac bridge is offline:

- Watch shows the selected Mac as offline.
- Approval and stop actions are unavailable.

## Complication Updates

Complication updates should prefer shared App Group state and WidgetKit timelines. The iPhone companion can trigger reloads after important changes, but reloads are budget-limited.

Use complication transfers only for high-priority state changes:

- Connection lost.
- Approval required.
- Task completed.
- Active tool changed.

Do not push every output chunk to complications.

## Privacy Rules

By default, watch payloads can include:

- Tool name.
- State.
- Short sanitized summary.
- Relative time.
- Approval required indicator.

By default, watch payloads must not include:

- Full prompts.
- Full shell commands.
- Full paths.
- Environment variables.
- Tokens.
- Raw CLI output.
- Raw heart-rate samples or detailed HealthKit history.

Health summaries sent beyond the iPhone must be derived labels such as `focused`, `active`, or `stressed` with confidence and coarse levels. Raw HealthKit samples stay on device.

## Testing Checklist

- [ ] Watch receives latest state through application context.
- [ ] Watch can send a reachable `sendMessage` action.
- [ ] Watch shows cached state when iPhone is unreachable.
- [ ] Queued updates deduplicate by event ID.
- [ ] Complication data does not include private text.
- [ ] Relay unavailable state is visible on watch.
- [ ] Mac offline state disables unsafe actions.
