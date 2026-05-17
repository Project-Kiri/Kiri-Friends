import { redactPayload } from "./redaction.js";
import type { BridgeClient, PluginEventEnvelope, PluginEventKind } from "./types.js";

// OpenClaw plugin events translate to PascalCase before reaching the
// Kiri Friends bridge. Mirrors
// .workspace/reference/clawd-on-desk/agents/openclaw.js.
const OPENCLAW_EVENT_MAP: Record<string, PluginEventKind> = {
  SessionStart: "session.started",
  UserPromptSubmit: "prompt.submitted",
  PreToolUse: "tool.started",
  PostToolUse: "tool.completed",
  PostToolUseFailure: "session.failed",
  Stop: "session.completed",
  StopFailure: "session.failed",
  PreCompact: "session.compacting",
  PostCompact: "session.completed",
  SessionEnd: "session.completed",
};

export function openclawLifecycleEvent(
  hookName: string,
  raw: Record<string, unknown>,
): PluginEventEnvelope {
  const resolvedHookName = stringOrUndefined(raw.hookEventName) ?? stringOrUndefined(raw.hook_event_name) ?? hookName;
  const event: PluginEventEnvelope = {
    version: 1,
    tool: "openclaw",
    event: OPENCLAW_EVENT_MAP[resolvedHookName] ?? "output.preview",
    createdAt: new Date().toISOString(),
    payload: {
      hookEventName: resolvedHookName,
      ...redactPayload(raw),
    },
  };
  const sessionId = stringOrUndefined(raw.sessionId) ?? stringOrUndefined(raw.session_id);
  const cwd = stringOrUndefined(raw.cwd);
  if (sessionId !== undefined) event.sessionId = sessionId;
  if (cwd !== undefined) event.cwd = cwd;
  return event;
}

export async function forwardOpenclawLifecycleEvent(
  hookName: string,
  raw: Record<string, unknown>,
  client: BridgeClient,
  timeoutMs = 600,
): Promise<void> {
  await client.send(openclawLifecycleEvent(hookName, raw), timeoutMs);
}

function stringOrUndefined(value: unknown): string | undefined {
  return typeof value === "string" ? value : undefined;
}
