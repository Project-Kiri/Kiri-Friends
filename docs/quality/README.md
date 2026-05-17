# Quality Documentation

Testing strategy, verification commands, and manual QA checklist.

## Documents

- [testing-quality.md](testing-quality.md) — full quality strategy for Core, plugins, relay, WatchConnectivity, widgets, notifications, and manual QA.

## Testing Strategy

### Unit Tests

Located in `Tests/KiriFriendsCoreTests/`. Focus on:

- Domain model behavior
- Protocol serialization/deserialization
- State management logic

### UI Tests

Located in `Tests/KiriFriendsWatchAppUITests/` (future). Focus on:

- Navigation flows
- Complication rendering
- Notification handling

### Manual QA Checklist

- [ ] App launches without crash
- [ ] All four tabs are accessible
- [ ] Status updates reflect CLI state
- [ ] Commands send successfully
- [ ] History shows recent interactions
- [ ] Complications update on watch face
- [ ] Notifications arrive for long-running tasks
- [ ] iPhone companion shows bridge status
