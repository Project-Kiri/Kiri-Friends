import assert from "node:assert/strict";
import test from "node:test";

import { claudeContinueOutput, claudeLifecycleEvent } from "../src/claude.js";
import { codexLifecycleEvent, codexPermissionEvent, handleCodexPermissionRequest } from "../src/codex.js";
import { addJsonHookEntry, removeKiriEntries } from "../src/installer.js";
import { resolveOpenCodeConfigDir } from "../src/opencode.js";
import { redactPayload } from "../src/redaction.js";
import type { BridgeClient } from "../src/types.js";

test("redacts likely secrets", () => {
  assert.deepEqual(redactPayload({ token: "abc", summary: "safe" }), {
    token: "[redacted]",
    summary: "safe",
  });
});

test("creates Codex permission event with sanitized tool input", () => {
  const event = codexPermissionEvent({
    session_id: "session-1",
    tool_name: "Bash",
    tool_input: { command: "npm test", apiKey: "secret" },
    cwd: "/tmp/project",
  });

  assert.equal(event.tool, "codex");
  assert.equal(event.event, "approval.requested");
  assert.equal(event.payload.summary, "npm test");
  assert.deepEqual(event.payload.toolInput, { command: "npm test", apiKey: "[redacted]" });
});

test("Codex permission handler returns null when bridge declines", async () => {
  const client: BridgeClient = {
    async send() {
      return null;
    },
  };

  assert.equal(await handleCodexPermissionRequest({}, client, 1), null);
});

test("Codex permission handler emits Codex response JSON for decisions", async () => {
  const client: BridgeClient = {
    async send() {
      return { decision: "allow" };
    },
  };
  const output = await handleCodexPermissionRequest({}, client, 1);
  assert.ok(output);
  assert.equal(JSON.parse(output as string).hookSpecificOutput.decision.behavior, "allow");
});

test("maps Claude lifecycle events", () => {
  const event = claudeLifecycleEvent("Ignored", {
    hook_event_name: "PreToolUse",
    session_id: "s",
    token: "secret",
  });

  assert.equal(event.tool, "claude-code");
  assert.equal(event.event, "tool.started");
  assert.equal(event.payload.token, "[redacted]");
  assert.equal(event.payload.hookEventName, "PreToolUse");
});

test("maps extended Claude hook events", () => {
  assert.equal(claudeLifecycleEvent("SessionStart", {}).event, "session.started");
  assert.equal(claudeLifecycleEvent("PreCompact", {}).event, "session.compacting");
  assert.equal(claudeLifecycleEvent("SubagentStop", {}).event, "subagent.completed");
});

test("emits standard Claude continue output", () => {
  const output = JSON.parse(claudeContinueOutput("Forwarded to Kiri Friends"));

  assert.equal(output.continue, true);
  assert.equal(output.suppressOutput, true);
  assert.equal(output.systemMessage, "Forwarded to Kiri Friends");
});

test("maps Codex lifecycle hooks from documented hook names", () => {
  const event = codexLifecycleEvent("SessionStart", { session_id: "s" });

  assert.equal(event.tool, "codex");
  assert.equal(event.event, "session.started");
  assert.equal(event.sessionId, "s");
});

test("resolves OpenCode config directories", () => {
  assert.equal(
    resolveOpenCodeConfigDir({ OPENCODE_CONFIG_DIR: "/custom" }, "/home/me"),
    "/custom",
  );
  assert.equal(
    resolveOpenCodeConfigDir({ XDG_CONFIG_HOME: "/xdg" }, "/home/me"),
    "/xdg/opencode",
  );
});

test("installer preserves non-Kiri hook entries", () => {
  const current = JSON.stringify({
    hooks: {
      PreToolUse: [{ hooks: [{ type: "command", command: "echo user" }] }],
    },
  });
  const plan = addJsonHookEntry(current, "/tmp/settings.json", "PreToolUse", "kiri hook", {
    matcher: "^Bash$",
    timeoutSec: 2,
    statusMessage: "Kiri Friends hook",
  });
  const installed = JSON.parse(plan.nextText);
  const removed = removeKiriEntries(plan.nextText);
  const parsed = JSON.parse(removed);

  assert.equal(plan.backupRequired, true);
  assert.equal(installed.hooks.PreToolUse[1].matcher, "^Bash$");
  assert.equal(installed.hooks.PreToolUse[1].hooks[0].timeout, 2);
  assert.equal(installed.hooks.PreToolUse[1].hooks[0].statusMessage, "Kiri Friends hook");
  assert.equal(installed.hooks.PreToolUse[1].hooks[0].marker, undefined);
  assert.equal(parsed.hooks.PreToolUse.length, 1);
  assert.equal(parsed.hooks.PreToolUse[0].hooks[0].command, "echo user");
});
