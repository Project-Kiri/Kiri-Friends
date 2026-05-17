import { redactPayload } from "./redaction.js";
import type { BridgeClient, PluginEventEnvelope, PluginEventKind } from "./types.js";

// Gemini CLI hook events are PascalCase. Mirrors
// .workspace/reference/clawd-on-desk/agents/gemini-cli.js. `PreCompress`
// uses an idle mapping per upstream behaviour: the hook runtime requests
// a preserved state from the bridge instead of swapping the displayed
// visual.
const GEMINI_EVENT_MAP: Record<string, PluginEventKind> = {
  SessionStart: "session.started",
  SessionEnd: "session.completed",
  BeforeAgent: "prompt.submitted",
  BeforeTool: "tool.started",
  AfterTool: "tool.completed",
  AfterAgent: "session.completed",
  Notification: "session.waiting",
  PreCompress: "session.compacting",
};

export function geminiLifecycleEvent(
  hookName: string,
  raw: Record<string, unknown>,
): PluginEventEnvelope {
  const resolvedHookName = stringOrUndefined(raw.hook_event_name) ?? stringOrUndefined(raw.hookEventName) ?? hookName;
  const event: PluginEventEnvelope = {
    version: 1,
    tool: "gemini-cli",
    event: GEMINI_EVENT_MAP[resolvedHookName] ?? "output.preview",
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

export async function forwardGeminiLifecycleEvent(
  hookName: string,
  raw: Record<string, unknown>,
  client: BridgeClient,
  timeoutMs = 600,
): Promise<void> {
  await client.send(geminiLifecycleEvent(hookName, raw), timeoutMs);
}

function stringOrUndefined(value: unknown): string | undefined {
  return typeof value === "string" ? value : undefined;
}
