# Kiri Friends Agent Guidelines

## Development Documentation

Use these documents as the project map before making architectural, runtime, UI, or workflow changes:

- `docs/README.md` — documentation index.
- `docs/product/information-architecture.md` — product scope and information architecture for watchOS.
- `docs/interfaces/watchos-swiftui-interface.md` — watchOS SwiftUI interface structure, complications, and navigation.
- `docs/core/cli-bridge.md` — CLIBridge protocol between iPhone companion and CLI tools.
- `docs/core/cli-plugins.md` — Claude Code, Codex, and OpenCode plugin/hook contracts.
- `docs/core/cli-adapters.md` — normalized CLI adapter behavior.
- `docs/server/relay-server.md` — Cloud Relay server routing, downlink delivery, presence, and retries.
- `docs/core/security-and-privacy.md` — trust boundaries, redaction, pairing, and approval safety.
- `docs/operations/app-store-distribution.md` — TestFlight and App Store submission process.
- `docs/quality/testing-quality.md` — testing and quality expectations.

watchOS-specific implementation guidance lives under `.agents/skills/`, especially:

- `.agents/skills/watchos-design-guidelines/SKILL.md`
- `.agents/skills/watchOS/SKILL.md`
- `.agents/skills/watchos-code-review/SKILL.md`
- `.agents/skills/kiri-friends-core/SKILL.md`

## Documentation Maintenance

When a change meaningfully alters product behavior, architecture, runtime configuration, communication protocol, testing expectations, or UI information architecture, update the relevant document in `docs/` in the same change set. Do not let implementation and documentation drift.

## UI Copy Constraints

- Avoid redundant copy. Do not repeat information already expressed by a title, metric, selected state, icon, or surrounding section.
- Prefer concise labels over explanatory text when the UI state is self-evident.
- Remove disabled placeholder actions unless they teach a real next step.
- Do not add low-information detail text such as "Current status", "selected", or repeated counts when nearby UI already communicates the same fact.
- Keep user-visible copy in English unless explicitly asked otherwise.

## watchOS Native Component Constraints

- Prefer native SwiftUI and watchOS controls (`List`, `Form`, `Button`, `Picker`, `Toggle`, `TabView`, `NavigationStack`) before custom components.
- Do not recreate native selection, navigation, or button behavior with overlays, fake masks, or hand-rolled hit targets.
- Prefer native watchOS APIs for complications (`CLKComplicationWidget`, `WidgetKit`) and notifications (`WKUserNotificationInterfaceController`).
- Keep custom views small and compositional. Extract only when it clarifies state, layout, or reuse.
- Respect the small screen size of Apple Watch. Prioritize glanceable information over dense content.
