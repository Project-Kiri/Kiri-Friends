import type { PresenceState, RelayEvent } from "./types.js";

export const debugScenarioNames = [
  "approval-shell",
  "approval-edit",
  "waiting-input",
  "running-tool",
  "failed-tool",
  "multi-agent",
] as const;

export type DebugScenarioName = typeof debugScenarioNames[number];

export type DebugScenarioDefinition = {
  name: DebugScenarioName;
  description: string;
  defaultPresence: PresenceState;
};

export type DebugScenarioOptions = {
  now?: Date;
  cwd?: string;
  sessionId?: string;
  tool?: string;
};

export type DebugScenarioEvent = {
  version: 1;
  tool: string;
  event: string;
  sessionId: string;
  cwd: string;
  createdAt: string;
  sensitivity: RelayEvent["sensitivity"];
  payload: Record<string, unknown>;
};

export const debugScenarioDefinitions: readonly DebugScenarioDefinition[] = [
  {
    name: "approval-shell",
    description: "A shell command approval hook with Approve and Deny actions.",
    defaultPresence: "waiting",
  },
  {
    name: "approval-edit",
    description: "A file edit approval hook with private preview content.",
    defaultPresence: "waiting",
  },
  {
    name: "waiting-input",
    description: "An input hook where the agent asks for a short reply.",
    defaultPresence: "waiting",
  },
  {
    name: "running-tool",
    description: "A normal running tool state without interactive buttons.",
    defaultPresence: "busy",
  },
  {
    name: "failed-tool",
    description: "A failed session state for error presentation checks.",
    defaultPresence: "idle",
  },
  {
    name: "multi-agent",
    description: "Multiple agents with one pending approval prioritized on Watch.",
    defaultPresence: "waiting",
  },
];

export function isDebugScenarioName(value: string): value is DebugScenarioName {
  return debugScenarioNames.includes(value as DebugScenarioName);
}

export function getDebugScenario(name: DebugScenarioName): DebugScenarioDefinition {
  const scenario = debugScenarioDefinitions.find((definition) => definition.name === name);
  if (!scenario) throw new Error(`unknown debug scenario: ${name}`);
  return scenario;
}

export function buildDebugScenarioEvents(
  name: DebugScenarioName,
  options: DebugScenarioOptions = {},
): DebugScenarioEvent[] {
  const base = options.now ?? new Date();
  const cwd = options.cwd ?? "/Users/debug/kiri-friends";
  const sessionId = options.sessionId ?? `debug-${name}`;
  const tool = options.tool ?? "codex";

  switch (name) {
    case "approval-shell":
      return [
        event(base, 0, { tool, sessionId, cwd, event: "session.started", payload: sessionPayload(tool, "Debug shell approval") }),
        event(base, 1, { tool, sessionId, cwd, event: "tool.started", payload: { title: "Bash", summary: "Preparing shell command", toolName: "Bash" } }),
        event(base, 2, {
          tool,
          sessionId,
          cwd,
          event: "approval.requested",
          sensitivity: "preview",
          payload: {
            title: "Approve shell command?",
            summary: "npm test",
            toolName: "Bash",
            command: "npm test",
            reason: "Debug scenario for approval buttons.",
          },
        }),
      ];
    case "approval-edit":
      return [
        event(base, 0, { tool, sessionId, cwd, event: "session.started", payload: sessionPayload(tool, "Debug edit approval") }),
        event(base, 1, { tool, sessionId, cwd, event: "tool.started", payload: { title: "Edit", summary: "Preparing file change", toolName: "Edit" } }),
        event(base, 2, {
          tool,
          sessionId,
          cwd,
          event: "approval.requested",
          sensitivity: "private",
          payload: {
            title: "Approve file edit?",
            summary: "Update README.md",
            toolName: "Edit",
            path: "README.md",
          },
        }),
      ];
    case "waiting-input":
      return [
        event(base, 0, { tool, sessionId, cwd, event: "session.started", payload: sessionPayload(tool, "Debug input request") }),
        event(base, 1, {
          tool,
          sessionId,
          cwd,
          event: "session.waiting",
          payload: {
            title: "Need your input",
            summary: "Pick a release note tone",
            prompt: "Should the release note be concise or detailed?",
          },
        }),
      ];
    case "running-tool":
      return [
        event(base, 0, { tool, sessionId, cwd, event: "session.started", payload: sessionPayload(tool, "Debug running state") }),
        event(base, 1, {
          tool,
          sessionId,
          cwd,
          event: "tool.started",
          payload: {
            title: "Running tests",
            summary: "Executing focused test suite",
            toolName: "Bash",
          },
        }),
      ];
    case "failed-tool":
      return [
        event(base, 0, { tool, sessionId, cwd, event: "session.started", payload: sessionPayload(tool, "Debug failure state") }),
        event(base, 1, { tool, sessionId, cwd, event: "tool.started", payload: { title: "Build", summary: "Compiling app", toolName: "xcodebuild" } }),
        event(base, 2, {
          tool,
          sessionId,
          cwd,
          event: "session.failed",
          sensitivity: "none",
          payload: {
            title: "Build failed",
            summary: "xcodebuild exited with code 65",
          },
        }),
      ];
    case "multi-agent":
      return [
        event(base, 0, { tool: "claude", sessionId: "debug-claude", cwd, event: "session.started", payload: sessionPayload("claude", "Planning UI polish") }),
        event(base, 1, { tool: "claude", sessionId: "debug-claude", cwd, event: "tool.started", payload: { title: "Reading files", summary: "Inspecting Watch views", toolName: "Read" } }),
        event(base, 2, { tool: "cursor", sessionId: "debug-cursor", cwd, event: "session.waiting", payload: { title: "Need input", summary: "Choose layout direction" } }),
        event(base, 3, {
          tool: "codex",
          sessionId: "debug-codex-approval",
          cwd,
          event: "approval.requested",
          sensitivity: "preview",
          payload: {
            title: "Approve shell command?",
            summary: "make test-server",
            toolName: "Bash",
            command: "make test-server",
          },
        }),
      ];
  }
}

function sessionPayload(tool: string, summary: string): Record<string, unknown> {
  return {
    title: tool,
    summary,
  };
}

function event(
  base: Date,
  offsetSeconds: number,
  input: {
    tool: string;
    sessionId: string;
    cwd: string;
    event: string;
    sensitivity?: RelayEvent["sensitivity"];
    payload: Record<string, unknown>;
  },
): DebugScenarioEvent {
  return {
    version: 1,
    tool: input.tool,
    event: input.event,
    sessionId: input.sessionId,
    cwd: input.cwd,
    createdAt: new Date(base.getTime() + offsetSeconds * 1000).toISOString(),
    sensitivity: input.sensitivity ?? "preview",
    payload: input.payload,
  };
}
