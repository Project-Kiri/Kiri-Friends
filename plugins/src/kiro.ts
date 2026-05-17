import { redactPayload } from "./redaction.js";
import type { BridgeClient, PluginEventEnvelope, PluginEventKind } from "./types.js";

// Kiro CLI hook events are camelCase. Mirrors
// .workspace/reference/clawd-on-desk/agents/kiro-cli.js.
const KIRO_EVENT_MAP: Record<string, PluginEventKind> = {
  agentSpawn: "session.started",
  userPromptSubmit: "prompt.submitted",
  preToolUse: "tool.started",
  postToolUse: "tool.completed",
  stop: "session.completed",
};

export function kiroLifecycleEvent(
  hookName: string,
  raw: Record<string, unknown>,
): PluginEventEnvelope {
  const resolvedHookName = stringOrUndefined(raw.hook_event_name) ?? stringOrUndefined(raw.hookEventName) ?? hookName;
  const event: PluginEventEnvelope = {
    version: 1,
    tool: "kiro-cli",
    event: KIRO_EVENT_MAP[resolvedHookName] ?? "output.preview",
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

export async function forwardKiroLifecycleEvent(
  hookName: string,
  raw: Record<string, unknown>,
  client: BridgeClient,
  timeoutMs = 600,
): Promise<void> {
  await client.send(kiroLifecycleEvent(hookName, raw), timeoutMs);
}

function stringOrUndefined(value: unknown): string | undefined {
  return typeof value === "string" ? value : undefined;
}
