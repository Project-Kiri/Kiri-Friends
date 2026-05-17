import { redactPayload } from "./redaction.js";
import type { BridgeClient, PluginEventEnvelope, PluginEventKind } from "./types.js";

// Kimi Code CLI hook events are PascalCase, identical to Claude Code's.
// Mirrors .workspace/reference/clawd-on-desk/agents/kimi-cli.js.
const KIMI_EVENT_MAP: Record<string, PluginEventKind> = {
  SessionStart: "session.started",
  SessionEnd: "session.completed",
  UserPromptSubmit: "prompt.submitted",
  PreToolUse: "tool.started",
  PostToolUse: "tool.completed",
  PostToolUseFailure: "session.failed",
  Stop: "session.completed",
  StopFailure: "session.failed",
  SubagentStart: "tool.started",
  SubagentStop: "subagent.completed",
  PreCompact: "session.compacting",
  PostCompact: "session.completed",
  Notification: "session.waiting",
};

export function kimiLifecycleEvent(
  hookName: string,
  raw: Record<string, unknown>,
): PluginEventEnvelope {
  const resolvedHookName = stringOrUndefined(raw.hook_event_name) ?? stringOrUndefined(raw.hookEventName) ?? hookName;
  const event: PluginEventEnvelope = {
    version: 1,
    tool: "kimi-cli",
    event: KIMI_EVENT_MAP[resolvedHookName] ?? "output.preview",
    createdAt: new Date().toISOString(),
    payload: {
      hookEventName: resolvedHookName,
      ...redactPayload(raw),
    },
  };
  const sessionId = stringOrUndefined(raw.session_id) ?? stringOrUndefined(raw.sessionId);
  const cwd = stringOrUndefined(raw.cwd);
  if (sessionId !== undefined) event.sessionId = sessionId;
  if (cwd !== undefined) event.cwd = cwd;
  return event;
}

export async function forwardKimiLifecycleEvent(
  hookName: string,
  raw: Record<string, unknown>,
  client: BridgeClient,
  timeoutMs = 600,
): Promise<void> {
  await client.send(kimiLifecycleEvent(hookName, raw), timeoutMs);
}

function stringOrUndefined(value: unknown): string | undefined {
  return typeof value === "string" ? value : undefined;
}
