# Watch Complications and Widgets

Kiri Friends uses WidgetKit complications and Smart Stack widgets to show CLI status at a glance. These surfaces must be useful without exposing private CLI content.

## Supported Families

Minimum supported WidgetKit families:

- `accessoryCircular`
- `accessoryCorner`
- `accessoryRectangular`
- `accessoryInline`

Smart Stack widgets should start with `accessoryRectangular` because it can show the most useful combination of tool, state, and time.

## Data Source

Complications and widgets read from `AppGroupSnapshotStore` (see
`apps/apple/Sources/KiriFriendsCore/AppGroupSnapshotStore.swift`)
backed by the shared App Group `group.com.kirifriends.shared`. The
iPhone companion's `BridgeRuntime.publishSnapshot()` writes a fresh
`ComplicationSnapshot` after every meaningful relay event and calls
`WidgetCenter.shared.reloadAllTimelines()` so the watch picks up the
update without waiting for the next scheduled refresh.

Stored shape:

```json
{
  "updatedAt": "2026-05-17T12:00:00Z",
  "shortStatus": "Approval",
  "detail": "Action needed +2",
  "symbolName": "hand.tap",
  "sensitivity": "none"
}
```

The `detail` field carries a `+N` suffix when the Mac Buddy is tracking
additional sessions beyond the primary one; this lets the complication
hint at multi-agent activity without listing each session.

The widget extension never talks to the Cloud Relay directly; the
iPhone companion owns relay auth, polling, and complication writes.

## Timeline Policy

Widget timelines should prefer predictable refreshes and explicit reloads for high-priority changes.

Recommended policy:

- Normal idle or running state: refresh every 5 minutes; the iPhone
  companion will trigger an immediate `reloadAllTimelines()` whenever
  it writes a new snapshot, so this interval mostly covers the case
  where the companion is suspended.
- Waiting for approval: reload immediately through local app state and provide a short expiry.
- Completed task: show completion briefly, then return to idle or last-known state.
- Offline state: show last updated time.

Do not reload more often than necessary. WidgetKit reloads are budget-limited.

## Family Content

### `accessoryCircular`

Best for a single state.

Content:

- Tool glyph or initials.
- Status ring or dot.
- No long text.

### `accessoryCorner`

Best for active or action-required state.

Content:

- Short label such as `Kiri`.
- Gauge or status arc.
- Optional state abbreviation.

### `accessoryRectangular`

Best for Smart Stack and richer watch faces.

Content:

- Tool name.
- State label.
- Relative time.
- One short sanitized summary when previews are enabled.

### `accessoryInline`

Best for a very short text status.

Examples:

- `Kiri idle`
- `Codex running`
- `Action needed`

Keep inline text under 20 characters when possible.

## Rendering Modes

Complication views should support:

- Full color.
- Accented.
- Vibrant.

Use system colors and `widgetAccentable()` for elements that should adopt the watch face accent color.

## Buddy Art on Watch

The Watch app renders the same buddy themes the Mac Buddy uses. Assets
ship inside `apps/apple/Sources/KiriFriendsWatchKit/Resources/Themes.xcassets/`,
organised by theme namespace (`clawd`, `calico`, `cloudling`). Each
imageset wraps a single SVG (clawd, cloudling) or APNG (calico)
sourced from
[clawd-on-desk](https://github.com/rullerzhou-afk/clawd-on-desk) and
redistributed under AGPL-3.0. Selection follows
`BuddySettings.activeManifestId`. The iPhone companion exposes a picker
(Settings -> Buddy -> Theme) that writes through
`BridgeRuntime.publishBuddySettings`. `BundledBuddyThemeRegistry` maps
the identifier back to a `BundledBuddyTheme` whose `assetName(for:)`
returns the namespaced Asset Catalog name passed to
`Image(_:bundle:)`. If a theme is missing an asset for a given
`BuddyPersonaState`, `BuddyStageView` falls back to an SF Symbol so the
watch stays glanceable while themes evolve. The Watch and Mac Buddy
asset copies are kept in sync via `make verify-watch-assets`.

## Privacy

Complications are visible on the watch face and in Always On contexts. Default rendering should show no private content.

Allowed:

- Tool name or icon.
- State.
- Generic action indicator.
- Relative freshness.

Not allowed:

- Prompt text.
- Shell command text.
- File paths.
- Error stack traces.
- Output snippets unless explicit preview settings allow them in the app, not on the watch face.

## Taps and Deep Links

Tapping a complication should open the most relevant watch view:

| State | Destination |
| --- | --- |
| `waitingForApproval` | Approval detail view. |
| `running` | Status tab. |
| `failed` | Recent result detail. |
| `offline` | Connection status detail. |
| `idle` | Status tab. |

## Smart Stack Relevance

Use higher relevance when:

- A permission approval is pending.
- A long-running task completed.
- The bridge connection changed from online to offline.
- The active tool changed.

Use low or no relevance for idle state.

## Placeholder and Snapshot

Placeholders should use realistic but generic data:

- Tool: `Kiri`
- State: `Ready`
- Summary: `CLI status`

Never use empty placeholders or private sample text.

## Testing Checklist

- [ ] All supported families render in Xcode previews.
- [ ] Full color, accented, and vibrant modes are legible.
- [ ] Complications show useful information within 1-2 seconds.
- [ ] Tapping each state opens the relevant watch context.
- [ ] Private content is not visible on watch faces.
- [ ] Timeline reloads are budget-aware.
- [ ] Offline state shows last updated time.
