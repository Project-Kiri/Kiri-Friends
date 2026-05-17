export type ToolId =
  | "claude-code"
  | "codex"
  | "copilot-cli"
  | "gemini-cli"
  | "cursor-agent"
  | "codebuddy"
  | "kiro-cli"
  | "kimi-cli"
  | "opencode"
  | "pi"
  | "openclaw"
  | "hermes";

export type PluginEventKind =
  | "session.started"
  | "prompt.submitted"
  | "tool.started"
  | "tool.completed"
  | "approval.requested"
  | "approval.completed"
  | "session.waiting"
  | "session.completed"
  | "session.failed"
  | "session.compacting"
  | "subagent.completed"
  | "output.preview";

export type PayloadSensitivity = "none" | "preview" | "private" | "secret";

export type PluginEventEnvelope = {
  version: 1;
  tool: ToolId;
  event: PluginEventKind;
  sessionId?: string;
  cwd?: string;
  createdAt: string;
  payload: Record<string, unknown>;
};

export type BridgeDecision = {
  decision: "allow" | "deny" | "decline";
  message?: string;
};

export type BridgeClient = {
  send(event: PluginEventEnvelope, timeoutMs: number): Promise<BridgeDecision | null>;
};

export type ClaudeHookOutput = {
  continue?: boolean;
  suppressOutput?: boolean;
  systemMessage?: string;
  decision?: "approve" | "block";
  reason?: string;
  hookSpecificOutput?: {
    permissionDecision?: "allow" | "deny" | "ask";
    updatedInput?: Record<string, unknown>;
  };
};
