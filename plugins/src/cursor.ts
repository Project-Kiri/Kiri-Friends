import { redactPayload } from "./redaction.js";
import type { BridgeClient, PluginEventEnvelope, PluginEventKind } from "./types.js";

// Cursor IDE Agent hook events are camelCase. Mirrors
// .workspace/reference/clawd-on-desk/agents/cursor-agent.js.
const CURSOR_EVENT_MAP: Record<string, PluginEventKind> = {
  sessionStart: "session.started",
  sessionEnd: "session.completed",
  beforeSubmitPrompt: "prompt.submitted",
  preToolUse: "tool.started",
  postToolUse: "tool.completed",
  postToolUseFailure: "tool.completed",
  stop: "session.completed",
  subagentStart: "tool.started",
  subagentStop: "subagent.completed",
  preCompact: "session.compacting",
  afterAgentThought: "prompt.submitted",
};

export function cursorLifecycleEvent(
  hookName: string,
  raw: Record<string, unknown>,
): PluginEventEnvelope {
  const resolvedHookName = stringOrUndefined(raw.hook_event_name) ?? stringOrUndefined(raw.hookEventName) ?? hookName;
  const event: PluginEventEnvelope = {
    version: 1,
    tool: "cursor-agent",
    event: CURSOR_EVENT_MAP[resolvedHookName] ?? "output.preview",
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

export async function forwardCursorLifecycleEvent(
  hookName: string,
  raw: Record<string, unknown>,
  client: BridgeClient,
  timeoutMs = 600,
): Promise<void> {
  await client.send(cursorLifecycleEvent(hookName, raw), timeoutMs);
}

function stringOrUndefined(value: unknown): string | undefined {
  return typeof value === "string" ? value : undefined;
}
