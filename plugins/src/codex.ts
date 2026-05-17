import { redactPayload, summarizeCommand } from "./redaction.js";
import type { BridgeClient, PluginEventEnvelope, PluginEventKind } from "./types.js";

export const CODEX_PERMISSION_WAIT_MS = 110_000;

const CODEX_EVENT_MAP: Record<string, PluginEventKind> = {
  SessionStart: "session.started",
  UserPromptSubmit: "prompt.submitted",
  PreToolUse: "tool.started",
  PostToolUse: "tool.completed",
  PermissionRequest: "approval.requested",
  Stop: "session.completed",
};

export function codexPermissionEvent(raw: Record<string, unknown>): PluginEventEnvelope {
  const toolInput = (raw.tool_input ?? {}) as Record<string, unknown>;
  const event: PluginEventEnvelope = {
    version: 1,
    tool: "codex",
    event: "approval.requested",
    createdAt: new Date().toISOString(),
    payload: {
      turnId: raw.turn_id,
      toolName: raw.tool_name,
      title: "Approve CLI action?",
      summary: summarizeCommand(toolInput),
      toolInput: redactPayload(toolInput),
    },
  };
  const sessionId = stringOrUndefined(raw.session_id);
  const cwd = stringOrUndefined(raw.cwd);
  if (sessionId !== undefined) event.sessionId = sessionId;
  if (cwd !== undefined) event.cwd = cwd;
  return event;
}

export function codexLifecycleEvent(
  hookName: string,
  raw: Record<string, unknown>,
): PluginEventEnvelope {
  const resolvedHookName = stringOrUndefined(raw.hook_event_name) ?? hookName;
  const event: PluginEventEnvelope = {
    version: 1,
    tool: "codex",
    event: CODEX_EVENT_MAP[resolvedHookName] ?? "output.preview",
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

export async function handleCodexPermissionRequest(
  raw: Record<string, unknown>,
  client: BridgeClient,
  timeoutMs = CODEX_PERMISSION_WAIT_MS,
): Promise<string | null> {
  const response = await client.send(codexPermissionEvent(raw), timeoutMs);
  if (!response || response.decision === "decline") return null;

  const decision: Record<string, unknown> = { behavior: response.decision };
  if (response.message) decision.message = response.message;
  return JSON.stringify({
    hookSpecificOutput: {
      hookEventName: "PermissionRequest",
      decision,
    },
  });
}

function stringOrUndefined(value: unknown): string | undefined {
  return typeof value === "string" ? value : undefined;
}
