# CLI Adapters

CLI adapters translate between Kiri Friends domain requests and tool-specific behavior for Claude Code, Codex, and OpenCode.

## Relationship to Plugins

Plugins and hooks are the tool-specific event sources. Adapters are the Mac bridge modules that normalize those events and decide which actions are supported for each CLI.

```text
Host CLI plugin or hook -> Mac bridge adapter -> CLIBridge event or request result
```

## Common Adapter Interface

Each adapter should define:

- Tool ID.
- Display name.
- Configuration paths.
- Supported hook or plugin events.
- Supported downlink commands.
- Session ID extraction.
- Redaction rules.
- Install and uninstall behavior.
- Health checks.

Tool IDs:

- `claude-code`
- `codex`
- `opencode`

## Normalized Session State

Adapters map tool-specific events into the Kiri Friends session state model.

| State | Meaning |
| --- | --- |
| `idle` | Tool is available but no task is active. |
| `running` | A task or tool call is active. |
| `waitingForInput` | The CLI is waiting for user input that is not a permission approval. |
| `waitingForApproval` | The CLI is waiting for approval or denial. |
| `failed` | The current task failed. |
| `completed` | The current task completed. |
| `unknown` | Adapter cannot determine state. |

## Normalized Events

| Event | Meaning |
| --- | --- |
| `prompt.submitted` | User submitted a prompt to the CLI. |
| `tool.started` | CLI started a tool action. |
| `tool.completed` | CLI completed a tool action. |
| `approval.requested` | CLI needs an approval decision. |
| `approval.completed` | Approval request was resolved. |
| `session.completed` | Session or turn completed. |
| `session.failed` | Session failed or produced an error. |
| `output.preview` | Short output preview is available. |

## Adapter Matrix

| Capability | Claude Code | Codex | OpenCode |
| --- | --- | --- | --- |
| Lifecycle events | Hooks | Hooks | Plugin |
| Permission approval | Hook-dependent | `PermissionRequest` | Plugin-dependent |
| Quick prompt | Future | Future | Future |
| Stop task | Future | Future | Future |
| Config backup | Required | Required | Required |
| Clean uninstall | Required | Required | Required |

The first implementation should treat quick prompt and stop task as capability-gated. UI should show only actions supported by the active adapter.

## Claude Code Adapter

Configuration:

- Settings: `~/.claude/settings.json`
- Slash commands: `~/.claude/commands/`

Expected hooks:

- `UserPromptSubmit`
- `PreToolUse`
- `PostToolUse`
- `Notification`
- `Stop`

Mapping:

| Hook | Normalized Event | State |
| --- | --- | --- |
| `UserPromptSubmit` | `prompt.submitted` | `running` |
| `PreToolUse` | `tool.started` | `running` |
| `PostToolUse` | `tool.completed` | `idle` |
| `Notification` | `approval.requested` or `session.waiting` | `waitingForApproval` or `waitingForInput` |
| `Stop` | `session.completed` | `completed` |

The adapter should inspect hook payloads when available to distinguish permission prompts from idle notifications.

## Codex Adapter

Configuration:

- Hooks: `~/.codex/hooks.json`
- Feature flags: `~/.codex/config.toml`
- Prompts: `~/.codex/prompts/`

Expected hooks:

- `UserPromptSubmit`
- `PreToolUse`
- `PostToolUse`
- `PermissionRequest`
- `Stop`

Mapping:

| Hook | Normalized Event | State |
| --- | --- | --- |
| `UserPromptSubmit` | `prompt.submitted` | `running` |
| `PreToolUse` | `tool.started` | `running` |
| `PostToolUse` | `tool.completed` | `idle` |
| `PermissionRequest` | `approval.requested` | `waitingForApproval` |
| `Stop` | `session.completed` | `completed` |

The Codex adapter must preserve native Codex fallback. If Kiri Friends cannot deliver an approval decision within the hook budget, the adapter should decline to decide.

## OpenCode Adapter

Configuration:

- Default config root: `~/.config/opencode`
- Environment override: `OPENCODE_CONFIG_DIR`
- XDG override: `XDG_CONFIG_HOME`
- Plugin path: `<config-root>/plugins/kiri-friends.js`
- Command path: `<config-root>/command/kiri-friends.md`

Expected plugin events:

- `tool.execute.before`
- `tool.execute.after`
- `session.idle`
- `session.error`

Mapping:

| Plugin Event | Normalized Event | State |
| --- | --- | --- |
| `tool.execute.before` | `tool.started` | `running` |
| `tool.execute.after` | `tool.completed` | `idle` |
| `session.idle` | `session.completed` | `completed` |
| `session.error` | `session.failed` | `failed` |

OpenCode plugin install and uninstall should manage only the Kiri Friends plugin file and command file.

## Redaction

Adapters should classify fields before forwarding them:

| Field Type | Default Sensitivity |
| --- | --- |
| Tool name | `none` |
| Working directory basename | `preview` |
| Full working directory | `private` |
| Shell command | `private` |
| Command summary | `preview` |
| Prompt text | `private` |
| Output preview | `preview` |
| Environment variables | `secret` |
| Credentials or tokens | `secret` |

The Mac bridge should never send `secret` fields to the Cloud Relay.

## Health Checks

Each adapter should provide a health report:

- Config path exists.
- Hook or plugin installed.
- Last event received.
- Last error.
- Supported commands.
- Required feature flags are enabled.

Health reports power iPhone companion setup screens and troubleshooting docs.

## Capability Negotiation

Adapters publish capabilities through the Mac bridge handshake:

```json
{
  "tool": "codex",
  "capabilities": [
    "events.lifecycle",
    "approvals.request",
    "approvals.decide"
  ]
}
```

The iPhone companion and watchOS UI should use capabilities to decide which actions are visible.
