import { redactPayload } from "./redaction.js";
import type { BridgeClient, ClaudeHookOutput, PluginEventEnvelope, PluginEventKind } from "./types.js";

const CLAUDE_EVENT_MAP: Record<string, PluginEventKind> = {
  SessionStart: "session.started",
  UserPromptSubmit: "prompt.submitted",
  PreToolUse: "tool.started",
  PostToolUse: "tool.completed",
  Notification: "session.waiting",
  Stop: "session.completed",
  SessionEnd: "session.completed",
  PreCompact: "session.compacting",
  SubagentStop: "subagent.completed",
};

export function claudeLifecycleEvent(
  hookName: string,
  raw: Record<string, unknown>,
): PluginEventEnvelope {
  const resolvedHookName = stringOrUndefined(raw.hook_event_name) ?? hookName;
  const event: PluginEventEnvelope = {
    version: 1,
    tool: "claude-code",
    event: CLAUDE_EVENT_MAP[resolvedHookName] ?? "output.preview",
    createdAt: new Date().toISOString(),
    payload: {
      hookEventName: resolvedHookName,
      ...redactPayload(raw),
    },
  };
  const sessionId = stringOrUndefined(raw.session_id);
  const cwd = stringOrUndefined(raw.cwd);
  if (sessionId !== undefined) event.sessionId = sessionId;
  if (cwd !== undefined) event.cwd = cwd;
  return event;
}

export async function forwardClaudeLifecycleEvent(
  hookName: string,
  raw: Record<string, unknown>,
  client: BridgeClient,
  timeoutMs = 600,
): Promise<void> {
  await client.send(claudeLifecycleEvent(hookName, raw), timeoutMs);
}

export function claudeContinueOutput(systemMessage?: string): string {
  const output: ClaudeHookOutput = {
    continue: true,
    suppressOutput: true,
  };
  if (systemMessage) output.systemMessage = systemMessage;
  return JSON.stringify(output);
}

function stringOrUndefined(value: unknown): string | undefined {
  return typeof value === "string" ? value : undefined;
}
