import { redactPayload } from "./redaction.js";
import type { BridgeClient, PluginEventEnvelope, PluginEventKind } from "./types.js";

// CodeBuddy uses a Claude Code-compatible PascalCase hook format.
// Mirrors .workspace/reference/clawd-on-desk/agents/codebuddy.js.
const CODEBUDDY_EVENT_MAP: Record<string, PluginEventKind> = {
  SessionStart: "session.started",
  SessionEnd: "session.completed",
  UserPromptSubmit: "prompt.submitted",
  PreToolUse: "tool.started",
  PostToolUse: "tool.completed",
  Stop: "session.completed",
  PermissionRequest: "approval.requested",
  Notification: "session.waiting",
  PreCompact: "session.compacting",
};

export function codebuddyLifecycleEvent(
  hookName: string,
  raw: Record<string, unknown>,
): PluginEventEnvelope {
  const resolvedHookName = stringOrUndefined(raw.hook_event_name) ?? stringOrUndefined(raw.hookEventName) ?? hookName;
  const event: PluginEventEnvelope = {
    version: 1,
    tool: "codebuddy",
    event: CODEBUDDY_EVENT_MAP[resolvedHookName] ?? "output.preview",
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

export async function forwardCodebuddyLifecycleEvent(
  hookName: string,
  raw: Record<string, unknown>,
  client: BridgeClient,
  timeoutMs = 600,
): Promise<void> {
  await client.send(codebuddyLifecycleEvent(hookName, raw), timeoutMs);
}

function stringOrUndefined(value: unknown): string | undefined {
  return typeof value === "string" ? value : undefined;
}
