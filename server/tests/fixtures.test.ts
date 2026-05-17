import assert from "node:assert/strict";
import { readFile } from "node:fs/promises";
import path from "node:path";
import test from "node:test";

test("loads shared plugin event fixture", async () => {
  const fixturePath = path.resolve("..", "fixtures", "plugin-event.codex.permission.json");
  const event = JSON.parse(await readFile(fixturePath, "utf8"));

  assert.equal(event.version, 1);
  assert.equal(event.tool, "codex");
  assert.equal(event.event, "approval.requested");
});
