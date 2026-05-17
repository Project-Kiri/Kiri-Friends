# Information Architecture

## Navigation Model

The watchOS app uses a tab-based navigation structure optimized for small screens:

```
┌─────────────────┐
│   Status Tab    │  <- Default landing: active CLI, current task
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
