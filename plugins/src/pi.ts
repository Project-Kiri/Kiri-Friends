import { redactPayload } from "./redaction.js";
import type { BridgeClient, PluginEventEnvelope, PluginEventKind } from "./types.js";

// Pi extension events translate from snake_case to PascalCase before
// reaching the Kiri Friends bridge. Mirrors
// .workspace/reference/clawd-on-desk/agents/pi.js plus the snake_case →
// PascalCase translation done by hooks/pi-extension-core.js upstream.
const PI_EVENT_MAP: Record<string, PluginEventKind> = {
  SessionStart: "session.started",
  UserPromptSubmit: "prompt.submitted",
  PreToolUse: "tool.started",
  PostToolUse: "tool.completed",
  PostToolUseFailure: "session.failed",
  Stop: "session.completed",
  PreCompact: "session.compacting",
  PostCompact: "session.completed",
  SessionEnd: "session.completed",
};

export function piLifecycleEvent(
  hookName: string,
  raw: Record<string, unknown>,
): PluginEventEnvelope {
  const resolvedHookName = stringOrUndefined(raw.hookEventName) ?? stringOrUndefined(raw.hook_event_name) ?? hookName;
  const event: PluginEventEnvelope = {
    version: 1,
    tool: "pi",
    event: PI_EVENT_MAP[resolvedHookName] ?? "output.preview",
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

export async function forwardPiLifecycleEvent(
  hookName: string,
  raw: Record<string, unknown>,
  client: BridgeClient,
  timeoutMs = 600,
): Promise<void> {
  await client.send(piLifecycleEvent(hookName, raw), timeoutMs);
}

function stringOrUndefined(value: unknown): string | undefined {
  return typeof value === "string" ? value : undefined;
}
