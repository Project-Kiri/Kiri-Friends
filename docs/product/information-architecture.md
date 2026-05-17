# Information Architecture

## Navigation Model

The watchOS app uses a tab-based navigation structure optimized for small screens:

```
┌─────────────────┐
│   Status Tab    │  <- Default landing: Kiri buddy, active CLI, primary action
├─────────────────┤
│ Commands Tab    │  <- Quick actions: send prompt, stop, restart
├─────────────────┤
│ History Tab     │  <- Recent conversations and responses
├─────────────────┤
│ Settings Tab    │  <- Complication config, notifications
└─────────────────┘
```

## Watch Faces and Complications

Kiri Friends provides complications for supported watch faces:

| Complication Type | Content |
|-------------------|---------|
| Graphic Corner | Active CLI tool icon + status dot |
| Graphic Circular | Status ring showing task progress |
| Modular Large | Current task description |
| Accessory Corner | Status indicator |
| Accessory Circular | Tool icon with status color |
| Accessory Inline | Short status text |

## Glanceable Information Hierarchy

Information displayed follows this priority order:

1. **Critical**: CLI errors, connection lost, action required
2. **Active**: Current task, running process, active tool
3. **Recent**: Last completed task, recent response preview
4. **Contextual**: Time since last activity, tool version

## Buddy Home

The Status tab is a buddy-first surface. Kiri's visible state is derived from normalized CLI state, approval urgency, connection state, and optional local health summaries:

- `waitingForApproval` maps to an attention state with a visible approve action.
- `running` maps to focused work.
- `completed` maps to a brief celebration.
- `failed` maps to a concerned state.
- Always On and wrist-down states reduce motion and redact sensitive text.

Custom buddy assets are managed on iPhone and transferred to Watch. The Watch keeps a built-in fallback buddy so the app remains useful if an asset pack is missing or invalid.
