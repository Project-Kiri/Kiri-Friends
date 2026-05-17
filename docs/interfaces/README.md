# Interface Documentation

watchOS SwiftUI UI, complications, notifications, and iPhone companion surfaces.

## Documents

- [watchos-swiftui-interface.md](watchos-swiftui-interface.md) — WatchKit interface structure, navigation, and view hierarchy.
- [watch-connectivity.md](watch-connectivity.md) — iPhone-to-Watch payloads, offline behavior, and action routing.
- [watch-complications-and-widgets.md](watch-complications-and-widgets.md) — WidgetKit complication and Smart Stack strategy.
- [watch-notifications.md](watch-notifications.md) — notification categories, actions, haptics, and privacy behavior.

## Interface Principles

1. **Native First**: Prefer `TabView`, `List`, `NavigationStack`, and native watchOS controls.
2. **Complication-First Design**: Design the status model around what complications need to display.
3. **Notification Integration**: Use actionable notifications for long-running CLI tasks.
4. **iPhone Companion**: The iOS app serves as the relay client, watch sync manager, and history browser.
