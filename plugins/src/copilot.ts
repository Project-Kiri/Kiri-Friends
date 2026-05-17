import { redactPayload } from "./redaction.js";
import type { BridgeClient, PluginEventEnvelope, PluginEventKind } from "./types.js";

// Copilot CLI hook event names are camelCase. Mirrors
// .workspace/reference/clawd-on-desk/agents/copilot-cli.js so the
// downstream Mac bridge can interpret events without an additional
// agent-side translation.
const COPILOT_EVENT_MAP: Record<string, PluginEventKind> = {
  sessionStart: "session.started",
  sessionEnd: "session.completed",
  userPromptSubmitted: "prompt.submitted",
  preToolUse: "tool.started",
  postToolUse: "tool.completed",
  errorOccurred: "session.failed",
  agentStop: "session.completed",
  subagentStart: "tool.started",
  subagentStop: "subagent.completed",
  preCompact: "session.compacting",
};

export function copilotLifecycleEvent(
  hookName: string,
  raw: Record<string, unknown>,
): PluginEventEnvelope {
  const resolvedHookName = stringOrUndefined(raw.hookEventName) ?? stringOrUndefined(raw.hook_event_name) ?? hookName;
  const event: PluginEventEnvelope = {
    version: 1,
    tool: "copilot-cli",
    event: COPILOT_EVENT_MAP[resolvedHookName] ?? "output.preview",
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

export async function forwardCopilotLifecycleEvent(
  hookName: string,
  raw: Record<string, unknown>,
  client: BridgeClient,
  timeoutMs = 600,
): Promise<void> {
  await client.send(copilotLifecycleEvent(hookName, raw), timeoutMs);
}

function stringOrUndefined(value: unknown): string | undefined {
  return typeof value === "string" ? value : undefined;
}
