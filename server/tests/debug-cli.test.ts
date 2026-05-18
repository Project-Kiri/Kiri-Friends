import assert from "node:assert/strict";
import { request as httpRequest } from "node:http";
import { Writable } from "node:stream";
import test from "node:test";

import { runDebugCLI, type SeedResult } from "../src/debug-cli.js";
import { listenHTTPServer } from "../src/http-server.js";
import { RelayStore } from "../src/relay-store.js";

type Response = {
  statusCode: number;
  body: string;
};

class CaptureStream extends Writable {
  private readonly chunks: Buffer[] = [];

  _write(chunk: Buffer | string, _encoding: BufferEncoding, callback: (error?: Error | null) => void): void {
    this.chunks.push(Buffer.isBuffer(chunk) ? chunk : Buffer.from(chunk));
    callback();
  }

  text(): string {
    return Buffer.concat(this.chunks).toString("utf8");
  }
}

async function bootStore(): Promise<{ port: number; close: () => Promise<void>; store: RelayStore }> {
  const store = new RelayStore({ tokenSecret: "test-secret" });
  const handle = await listenHTTPServer({ store, port: 0, host: "127.0.0.1" });
  return { port: handle.port, close: handle.close, store };
}

async function performRequest(
  port: number,
  method: string,
  path: string,
  options: { token?: string; body?: unknown } = {},
): Promise<Response> {
  const payload = options.body !== undefined ? JSON.stringify(options.body) : undefined;
  return await new Promise((resolve, reject) => {
    const headers: Record<string, string> = {};
    if (options.token) headers.Authorization = `Bearer ${options.token}`;
    if (payload !== undefined) {
      headers["Content-Type"] = "application/json";
      headers["Content-Length"] = String(Buffer.byteLength(payload));
    }
    const req = httpRequest(
      {
        method,
        hostname: "127.0.0.1",
        port,
        path,
        headers,
      },
      (response) => {
        const chunks: Buffer[] = [];
        response.on("data", (chunk: Buffer) => chunks.push(chunk));
        response.on("end", () => {
          resolve({
            statusCode: response.statusCode ?? 0,
            body: Buffer.concat(chunks).toString("utf8"),
          });
        });
      },
    );
    req.on("error", reject);
    if (payload !== undefined) req.write(payload);
    req.end();
  });
}

async function runJSON(args: string[]): Promise<unknown> {
  const stdout = new CaptureStream();
  const stderr = new CaptureStream();
  const exitCode = await runDebugCLI([...args, "--json"], { stdout, stderr, env: {} });
  assert.equal(exitCode, 0, stderr.text());
  return JSON.parse(stdout.text());
}

test("debug seed creates paired devices, events, presence, and a pending request", async () => {
  const { port, close } = await bootStore();
  try {
    const result = await runJSON([
      "seed",
      "--url",
      `http://127.0.0.1:${port}`,
      "--scenario",
      "approval-shell",
      "--user-id",
      "debug-user",
    ]) as SeedResult;

    assert.equal(result.userId, "debug-user");
    assert.equal(result.scenario, "approval-shell");
    assert.equal(result.events.length, 3);
    assert.equal(result.request?.kind, "approval.allow");
    assert.equal(result.pairing.iphoneDeviceId, result.iphone.deviceId);
    assert.equal(result.pairing.macDeviceId, result.mac.deviceId);

    const events = await performRequest(port, "GET", "/v1/events", {
      token: result.iphone.deviceToken,
    });
    assert.equal(events.statusCode, 200);
    const parsedEvents = JSON.parse(events.body) as { events: Array<{ event: string }> };
    assert.deepEqual(parsedEvents.events.map((event) => event.event), [
      "session.started",
      "tool.started",
      "approval.requested",
    ]);

    const presence = await performRequest(port, "GET", "/v1/presence", {
      token: result.iphone.deviceToken,
    });
    const parsedPresence = JSON.parse(presence.body) as { presence: Array<{ deviceId: string; state: string }> };
    assert.equal(parsedPresence.presence.find((record) => record.deviceId === result.mac.deviceId)?.state, "waiting");

    const pending = await performRequest(port, "GET", "/v1/requests/pending", {
      token: result.mac.deviceToken,
    });
    const parsedPending = JSON.parse(pending.body) as { requests: Array<{ requestId: string; kind: string }> };
    assert.equal(parsedPending.requests.length, 1);
    assert.equal(parsedPending.requests[0]?.kind, "approval.allow");
  } finally {
    await close();
  }
});

test("debug CLI injects scenarios and drives request acknowledgement", async () => {
  const { port, close, store } = await bootStore();
  try {
    const relayURL = `http://127.0.0.1:${port}`;
    const seed = await runJSON([
      "seed",
      "--url",
      relayURL,
      "--scenario",
      "running-tool",
      "--no-request",
      "--user-id",
      "debug-user-2",
    ]) as SeedResult;

    const scenario = await runJSON([
      "scenario",
      "waiting-input",
      "--url",
      relayURL,
      "--mac-token",
      seed.mac.deviceToken,
      "--session-id",
      "debug-input-session",
    ]) as { scenario: string; events: Array<{ event: string; sessionId?: string }> };
    assert.equal(scenario.scenario, "waiting-input");
    assert.deepEqual(scenario.events.map((event) => event.event), ["session.started", "session.waiting"]);

    const queued = await runJSON([
      "request",
      "prompt.sendQuick",
      "--url",
      relayURL,
      "--iphone-token",
      seed.iphone.deviceToken,
      "--mac-device-id",
      seed.mac.deviceId,
      "--session-id",
      "debug-input-session",
      "--text",
      "Ship it",
    ]) as { requestId: string; kind: string; status: string };
    assert.equal(queued.kind, "prompt.sendQuick");
    assert.equal(queued.status, "queued");

    const acked = await runJSON([
      "ack",
      queued.requestId,
      "--url",
      relayURL,
      "--mac-token",
      seed.mac.deviceToken,
      "--status",
      "completed",
      "--result-json",
      "{\"queued\":true}",
    ]) as { requestId: string; status: string; result?: { queued?: boolean } };
    assert.equal(acked.status, "completed");
    assert.equal(acked.result?.queued, true);
    assert.equal(store.getRequest(queued.requestId)?.status, "completed");
  } finally {
    await close();
  }
});
