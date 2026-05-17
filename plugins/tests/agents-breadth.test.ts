import assert from "node:assert/strict";
import test from "node:test";

import { codebuddyLifecycleEvent } from "../src/codebuddy.js";
import { copilotLifecycleEvent } from "../src/copilot.js";
import { cursorLifecycleEvent } from "../src/cursor.js";
import { geminiLifecycleEvent } from "../src/gemini.js";
import { hermesLifecycleEvent } from "../src/hermes.js";
import { kimiLifecycleEvent } from "../src/kimi.js";
import { kiroLifecycleEvent } from "../src/kiro.js";
import { openclawLifecycleEvent } from "../src/openclaw.js";
import { piLifecycleEvent } from "../src/pi.js";

test("Copilot CLI maps camelCase hook events", () => {
  const event = copilotLifecycleEvent("preToolUse", { sessionId: "s", token: "secret" });
  assert.equal(event.tool, "copilot-cli");
  assert.equal(event.event, "tool.started");
  assert.equal(event.sessionId, "s");
  assert.equal(event.payload.token, "[redacted]");
});

test("Gemini CLI maps PascalCase hook events including PreCompress", () => {
  assert.equal(geminiLifecycleEvent("PreCompress", {}).event, "session.compacting");
  assert.equal(geminiLifecycleEvent("BeforeAgent", {}).event, "prompt.submitted");
  assert.equal(geminiLifecycleEvent("AfterAgent", {}).event, "session.completed");
});

test("Cursor agent maps before/after submit hook events", () => {
  assert.equal(cursorLifecycleEvent("beforeSubmitPrompt", {}).event, "prompt.submitted");
  assert.equal(cursorLifecycleEvent("subagentStop", {}).event, "subagent.completed");
});

test("CodeBuddy maps Claude-compatible hook events", () => {
  assert.equal(codebuddyLifecycleEvent("PreToolUse", {}).event, "tool.started");
  assert.equal(codebuddyLifecycleEvent("PermissionRequest", {}).event, "approval.requested");
});

test("Kiro CLI maps the minimal hook surface", () => {
  assert.equal(kiroLifecycleEvent("agentSpawn", {}).event, "session.started");
  assert.equal(kiroLifecycleEvent("stop", {}).event, "session.completed");
});

test("Kimi CLI maps Claude-compatible failure events", () => {
  assert.equal(kimiLifecycleEvent("PostToolUseFailure", {}).event, "session.failed");
  assert.equal(kimiLifecycleEvent("Notification", {}).event, "session.waiting");
});

test("Pi extension maps translated PascalCase events", () => {
  const event = piLifecycleEvent("PreToolUse", { sessionId: "s", cwd: "/tmp" });
  assert.equal(event.tool, "pi");
  assert.equal(event.event, "tool.started");
  assert.equal(event.cwd, "/tmp");
});

test("OpenClaw plugin maps full lifecycle including stop failures", () => {
  assert.equal(openclawLifecycleEvent("StopFailure", {}).event, "session.failed");
  assert.equal(openclawLifecycleEvent("SessionEnd", {}).event, "session.completed");
});

test("Hermes plugin maps the documented short lifecycle", () => {
  assert.equal(hermesLifecycleEvent("SessionStart", {}).event, "session.started");
  assert.equal(hermesLifecycleEvent("PostToolUseFailure", {}).event, "session.failed");
});

test("Unknown hook events fall through to output.preview", () => {
  assert.equal(copilotLifecycleEvent("totallyUnknown", {}).event, "output.preview");
  assert.equal(kimiLifecycleEvent("AlsoUnknown", {}).event, "output.preview");
});
