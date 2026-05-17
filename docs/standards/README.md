# Implementation Standards

Focused implementation standards for watchOS UI and communication patterns.

## WatchOS UI Standards

### Screen Size Considerations

- Design for the smallest supported Apple Watch (40mm)
- Use `GeometryReader` sparingly; prefer fixed sizes from `WKInterfaceDevice`
- Keep touch targets at least 44x44 points

### Typography

- Use `Font.system()` with text styles, not hardcoded sizes
- `headline` for card titles
- `body` for primary content
- `caption` for secondary metadata
- `caption2` for timestamps

### Color

- Use semantic colors (`Color.red`, `Color.green`) for status indicators
- Respect `ColorScheme` (light/dark mode)
- Avoid custom colors that may conflict with accessibility settings

## Communication Standards

### Protocol Versioning

- Increment `version` field for breaking changes
- Maintain backward compatibility for at least one major version
- Document deprecated fields before removal

### Error Handling

- Always return a response, even for errors
- Include human-readable `error.message` and machine-readable `error.code`
- Log errors on both sides of the bridge
