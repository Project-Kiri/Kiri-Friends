# CLI Plugin and Hook Contracts

Kiri Friends integrates with twelve CLI hosts through small local plugins or hooks: Claude Code, Codex CLI, Copilot CLI, Gemini CLI, Cursor Agent, CodeBuddy, Kiro CLI, Kimi Code CLI, OpenCode, Pi, OpenClaw, and Hermes Agent. These integrations are the first hop between a host CLI and the Mac bridge.

## Boundary

Plugins and hooks:

- Collect host CLI lifecycle events.
- Forward normalized event envelopes to the CLI Host Bridge.
- Return host-specific decisions when the host CLI requires a response.
- Fail quickly and let the host CLI continue with native behavior.

Plugins and hooks do not:

- Talk directly to Apple Watch.
- Talk directly to the iPhone companion.
- Own Cloud Relay authentication.
- Store long-term session history.
- Execute cross-CLI business logic.

## Local Transport

Preferred local transports:

1. Unix domain socket at `~/.kirifriends/bridge.sock`.
2. Localhost HTTP on `127.0.0.1` for tools that cannot use Unix sockets.

The CLI Host Bridge owns both endpoints. Plugins should use short client timeouts and never assume the bridge is running. The Cloud Relay Server is the only cross-device message relay; plugins never talk to it directly.

The TypeScript `LocalBridgeClient` resolves localhost HTTP targets in this
order: explicitly configured port, `KIRI_BRIDGE_PORT`, runtime JSON
configuration, configured fallback ports, then the default `7474`. This
mirrors Clawd-on-Desk's runtime config fallback while keeping Kiri's Cloud
Relay credentials out of plugins.

## Common Plugin Event Envelope

```json
{
  "version": 1,
  "tool": "codex",
  "event": "permission.requested",
  "sessionId": "session-id-from-host",
  "cwd": "/Users/example/project",
  "createdAt": "2026-05-17T12:00:00Z",
  "sensitivity": "preview",
  "payload": {
    "title": "Approve shell command?",
    "summary": "Run tests"
  }
}
```

## Timeout Policy

Hook timeout budgets must be shorter than the host CLI timeout.

Recommended defaults:

| Hook Type | Max Kiri Wait |
| --- | --- |
| Fire-and-forget lifecycle event | 600 ms |
| Status update with local bridge acknowledgement | 2 seconds |
| Permission request that needs watch decision | Host timeout minus at least 5 seconds |

When a timeout occurs, the plugin should return no Kiri-specific decision unless the host CLI requires an explicit safe response.

## Claude Code

Claude Code integration should use Claude Code hooks where available.

Initial hook mapping:

| Claude Code Hook | Kiri Event |
| --- | --- |
| `UserPromptSubmit` | `prompt.submitted` |
| `PreToolUse` | `tool.started` |
| `PostToolUse` | `tool.completed` |
| `Notification` | `session.waiting` |
| `Stop` | `session.completed` |

Claude hook behavior:

- Read hook payload from stdin.
- Forward a normalized event to the Mac bridge.
- Send diagnostics to stderr.
- Do not block the host CLI on non-critical event forwarding.

Claude permission or notification events can create watch notifications, but the watch path must not be required for Claude to continue.

## Codex

Codex integration should support lifecycle hooks and `PermissionRequest`.

Initial hook mapping:

| Codex Hook | Kiri Event |
| --- | --- |
| `UserPromptSubmit` | `prompt.submitted` |
| `PreToolUse` | `tool.started` |
| `PostToolUse` | `tool.completed` |
| `PermissionRequest` | `approval.requested` |
| `Stop` | `session.completed` |

Codex requires special care because `PermissionRequest` can affect whether a CLI action proceeds.

### PermissionRequest Contract

Input:

- Read Codex hook payload from stdin.
- Extract session, turn, tool name, tool input, and working directory.
- Redact or summarize sensitive tool input before sending it to the relay path.

Output:

- Write only Codex-approved response JSON to stdout when Kiri returns a decision.
- Write diagnostics to stderr.
- If the Mac bridge, relay, phone, or watch does not respond before the budget, emit no decision and let Codex fall back to its native approval flow.

The bridge path must never cause Codex to hang indefinitely.

### Feature Flag

Codex hook installation may require a feature flag in the user's Codex configuration. Installer documentation must detect and explain this requirement before writing hook entries.

## OpenCode

OpenCode integration should use a plugin file rather than JSON hook configuration.

Initial event mapping:

| OpenCode Event | Kiri Event |
| --- | --- |
| `tool.execute.before` | `tool.started` |
| `tool.execute.after` | `tool.completed` |
| `session.idle` | `session.completed` |
| `session.error` | `session.failed` |

OpenCode configuration paths should respect:

- `OPENCODE_CONFIG_DIR`
- `XDG_CONFIG_HOME`
- Default `~/.config/opencode`

The plugin should be installed into the user's OpenCode plugin directory and removed cleanly on uninstall.

## Extended Agent Roster

The remaining nine agents shipped with the Mac Buddy port follow the same plugin envelope. Their hook event vocabularies are documented inline; the canonical Swift mapping lives in `apps/apple/Sources/KiriFriendsMacBuddyKit/Agents/AgentRegistry.swift` and the TypeScript hook mappers live in `plugins/src/<agent>.ts`.

### Copilot CLI

| Copilot Hook | Kiri Event |
| --- | --- |
| `sessionStart` | `session.started` |
| `userPromptSubmitted` | `prompt.submitted` |
| `preToolUse` | `tool.started` |
| `postToolUse` | `tool.completed` |
| `errorOccurred` | `session.failed` |
| `agentStop` | `session.completed` |
| `subagentStart` | `tool.started` |
| `subagentStop` | `subagent.completed` |
| `preCompact` | `session.compacting` |

Hook configuration lives at `~/.copilot/hooks/hooks.json` and is the only integration that does not auto-register on bridge launch (the user must opt-in once).

### Gemini CLI

| Gemini Hook | Kiri Event |
| --- | --- |
| `SessionStart` | `session.started` |
| `BeforeAgent` | `prompt.submitted` |
| `BeforeTool` / `AfterTool` | `tool.started` / `tool.completed` |
| `AfterAgent` | `session.completed` |
| `Notification` | `session.waiting` |
| `PreCompress` | `session.compacting` |

Hook configuration lives at `~/.gemini/settings.json`.

### Cursor Agent

| Cursor Hook | Kiri Event |
| --- | --- |
| `beforeSubmitPrompt` | `prompt.submitted` |
| `preToolUse` / `postToolUse` | `tool.started` / `tool.completed` |
| `stop` | `session.completed` |
| `subagentStart` / `subagentStop` | `tool.started` / `subagent.completed` |
| `preCompact` | `session.compacting` |
| `afterAgentThought` | `prompt.submitted` |

Hook configuration lives at `~/.cursor/hooks.json`.

### CodeBuddy

CodeBuddy hooks reuse the Claude Code PascalCase vocabulary verbatim. Configuration lives at `~/.codebuddy/settings.json`. The Mac bridge accepts the same hook payload shape as Claude Code; the only routing difference is `agent_id=codebuddy`.

### Kiro CLI

Kiro lacks global hooks. The installer must inject per-agent hook entries into each agent JSON under `~/.kiro/agents/`. The Mac bridge tracks Kiro sessions by cwd because Kiro reuses `sessionId="default"`.

### Kimi Code CLI

Kimi hooks live in `~/.kimi/config.toml` under `[[hooks]]` entries. The hook vocabulary mirrors Claude Code's PascalCase set.

### Pi

Pi exposes lifecycle events through a global extension under `~/.pi/agent/extensions/clawd-on-desk`. The Mac bridge accepts the same envelope; the agent identifier is `pi`. Permission bubbles are supported for `bash`, `write`, and `edit` tool calls.

### OpenClaw

OpenClaw plugin events land via `~/.openclaw/openclaw.json` plugin configuration. State events are supported; permission bubbles are not yet supported by upstream OpenClaw.

### Hermes Agent

Hermes plugin events arrive from a Python plugin installed under Hermes' managed plugin directory. The hook surface is the smallest of the roster (lifecycle + tool failure). Permission bubbles are not supported.

## Command Downlink

Some host CLIs may support commands initiated from Kiri Friends.

Supported command categories:

- `status.get`
- `task.stop`
- `prompt.send`
- `approval.decide`

Each adapter must document which commands are supported. Unsupported commands should return `adapter_unsupported`.

## Installation Safety

Installers must:

- Detect existing CLI configuration.
- Back up files before modification.
- Merge Kiri-owned entries without overwriting unrelated user settings.
- Use stable markers that uninstallers can identify later.
- Support dry-run output before writing.
- Warn when a host CLI must be restarted before hooks load.

Uninstallers must:

- Remove only Kiri-owned entries.
- Preserve user custom hooks and plugins.
- Back up files before rewriting.
- Offer token revocation when security-sensitive local tokens were created.

## Failure Behavior

| Failure | Expected Behavior |
| --- | --- |
| CLI Host Bridge not running | Plugin exits quickly; host CLI continues. |
| Cloud Relay unavailable | CLI Host Bridge records local state; permission hooks fall back when needed. |
| iPhone offline | Relay queues safe requests or expires action requests. |
| Watch unavailable | iPhone shows state; permission hooks fall back before host timeout. |
| Invalid plugin payload | Plugin logs diagnostics and avoids mutating CLI behavior. |

## Testing Requirements

Plugin tests should cover:

- Payload parsing.
- Redaction.
- Timeout behavior.
- Stdout purity for response hooks.
- Install merge behavior.
- Uninstall preservation of user-owned config.
- Unsupported command handling.
