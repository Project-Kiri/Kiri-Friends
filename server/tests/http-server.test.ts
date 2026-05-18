import assert from "node:assert/strict";
import { request as httpRequest } from "node:http";
import test from "node:test";

import { listenHTTPServer } from "../src/http-server.js";
import { RelayStore } from "../src/relay-store.js";

type Response = {
  statusCode: number;
  body: string;
};

async function performRequest(
  port: number,
  method: string,
  path: string,
  options: { token?: string; body?: unknown } = {},
): Promise<Response> {
  const payload = options.body !== undefined ? JSON.stringify(options.body) : undefined;
  return await new Promise((resolve, reject) => {
    const headers: Record<string, string> = {};
    if (options.token) headers["Authorization"] = `Bearer ${options.token}`;
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

async function bootStore(): Promise<{ port: number; close: () => Promise<void>; store: RelayStore }> {
  const store = new RelayStore({ tokenSecret: "test-secret" });
  const handle = await listenHTTPServer({ store, port: 0, host: "127.0.0.1" });
  return { port: handle.port, close: handle.close, store };
}

test("healthz is unauthenticated", async () => {
  const { port, close } = await bootStore();
  try {
    const response = await performRequest(port, "GET", "/healthz");
    assert.equal(response.statusCode, 200);
    assert.deepEqual(JSON.parse(response.body), { status: "ok" });
  } finally {
    await close();
  }
});

test("registers devices and approves pairing over HTTP", async () => {
  const { port, close } = await bootStore();
  try {
    const iphoneResponse = await performRequest(port, "POST", "/v1/devices/iphone", {
      body: { userId: "user-1", name: "Steven iPhone" },
    });
    assert.equal(iphoneResponse.statusCode, 201);
    const iphone = JSON.parse(iphoneResponse.body) as { deviceId: string; deviceToken: string };

    const macResponse = await performRequest(port, "POST", "/v1/devices/mac", {
      body: { userId: "user-1", name: "MacBook" },
    });
    assert.equal(macResponse.statusCode, 201);
    const mac = JSON.parse(macResponse.body) as { deviceId: string; pairingCode: string };
    assert.equal(mac.pairingCode.length, 6);

    const pairingResponse = await performRequest(port, "POST", "/v1/pairings/approve", {
      token: iphone.deviceToken,
      body: { pairingCode: mac.pairingCode },
    });
    assert.equal(pairingResponse.statusCode, 201);
    const pairing = JSON.parse(pairingResponse.body) as { iphoneDeviceId: string; macDeviceId: string };
    assert.equal(pairing.iphoneDeviceId, iphone.deviceId);
    assert.equal(pairing.macDeviceId, mac.deviceId);
  } finally {
    await close();
  }
});

test("ingest event requires Mac bridge auth", async () => {
  const { port, close, store } = await bootStore();
  try {
    const unauthenticated = await performRequest(port, "POST", "/v1/plugin-events", {
      body: { event: "tool.started" },
    });
    assert.equal(unauthenticated.statusCode, 401);

    const iphone = store.registerIPhone("user-1", "iPhone");
    const wrongRole = await performRequest(port, "POST", "/v1/plugin-events", {
      token: iphone.deviceToken,
      body: { event: "tool.started" },
    });
    assert.equal(wrongRole.statusCode, 403);

    const mac = store.registerMac("user-1", "MacBook");
    const accepted = await performRequest(port, "POST", "/v1/plugin-events", {
      token: mac.deviceToken,
      body: {
        version: 1,
        tool: "codex",
        event: "tool.started",
        sessionId: "s-1",
        cwd: "/tmp/project",
        createdAt: "2026-05-17T12:00:00Z",
        sensitivity: "preview",
        payload: { toolName: "Bash" },
      },
    });
    assert.equal(accepted.statusCode, 201);
    const stored = JSON.parse(accepted.body) as {
      version?: number;
      tool?: string;
      event: string;
      sessionId?: string;
      cwd?: string;
      createdAt: string;
      payload: Record<string, unknown>;
    };
    assert.equal(stored.version, 1);
    assert.equal(stored.tool, "codex");
    assert.equal(stored.event, "tool.started");
    assert.equal(stored.sessionId, "s-1");
    assert.equal(stored.cwd, "/tmp/project");
    assert.equal(stored.createdAt, "2026-05-17T12:00:00Z");
    assert.deepEqual(stored.payload, { toolName: "Bash" });
  } finally {
    await close();
  }
});

test("list events returns ingested events for the calling user only", async () => {
  const { port, close, store } = await bootStore();
  try {
    const iphone = store.registerIPhone("user-1", "iPhone");
    const mac = store.registerMac("user-1", "MacBook");

    await performRequest(port, "POST", "/v1/plugin-events", {
      token: mac.deviceToken,
      body: { event: "session.started", sessionId: "a", payload: {} },
    });
    await performRequest(port, "POST", "/v1/plugin-events", {
      token: mac.deviceToken,
      body: { event: "tool.started", sessionId: "a", payload: {} },
    });

    const listed = await performRequest(port, "GET", "/v1/events", {
      token: iphone.deviceToken,
    });
    assert.equal(listed.statusCode, 200);
    const parsed = JSON.parse(listed.body) as { events: Array<{ event: string }> };
    assert.equal(parsed.events.length, 2);
    assert.deepEqual(parsed.events.map((event) => event.event), ["session.started", "tool.started"]);
  } finally {
    await close();
  }
});

test("list events honours the since cursor", async () => {
  const { port, close, store } = await bootStore();
  try {
    const iphone = store.registerIPhone("user-1", "iPhone");
    const mac = store.registerMac("user-1", "MacBook");
    await performRequest(port, "POST", "/v1/plugin-events", {
      token: mac.deviceToken,
      body: { event: "session.started", sessionId: "a", payload: {} },
    });
    const second = await performRequest(port, "POST", "/v1/plugin-events", {
      token: mac.deviceToken,
      body: { event: "tool.started", sessionId: "a", payload: {} },
    });
    const secondEventId = (JSON.parse(second.body) as { eventId: string }).eventId;

    const listed = await performRequest(port, "GET", `/v1/events?since=${secondEventId}`, {
      token: iphone.deviceToken,
    });
    const parsed = JSON.parse(listed.body) as { events: Array<{ event: string }> };
    assert.equal(parsed.events.length, 0);
  } finally {
    await close();
  }
});

test("enqueue request requires iPhone auth", async () => {
  const { port, close, store } = await bootStore();
  try {
    const iphone = store.registerIPhone("user-1", "iPhone");
    const mac = store.registerMac("user-1", "MacBook");

    const queued = await performRequest(port, "POST", "/v1/requests", {
      token: iphone.deviceToken,
      body: {
        targetDeviceId: mac.deviceId,
        sessionId: "session-1",
        kind: "approval.decide",
        expiresAt: new Date(Date.now() + 60_000).toISOString(),
        idempotencyKey: "k-1",
        payload: { decision: "allow" },
      },
    });
    assert.equal(queued.statusCode, 202);

    const pending = await performRequest(port, "GET", "/v1/requests/pending", {
      token: mac.deviceToken,
    });
    const parsed = JSON.parse(pending.body) as { requests: Array<{ kind: string }> };
    assert.equal(parsed.requests.length, 1);
    const queuedKind = parsed.requests[0]?.kind ?? null;
    assert.equal(queuedKind, "approval.decide");
  } finally {
    await close();
  }
});

test("acks pending requests with completion payloads", async () => {
  const { port, close, store } = await bootStore();
  try {
    const iphone = store.registerIPhone("user-1", "iPhone");
    const mac = store.registerMac("user-1", "MacBook");
    const queued = await performRequest(port, "POST", "/v1/requests", {
      token: iphone.deviceToken,
      body: {
        targetDeviceId: mac.deviceId,
        kind: "status.refresh",
        expiresAt: new Date(Date.now() + 60_000).toISOString(),
        idempotencyKey: "refresh-1",
        payload: {},
      },
    });
    const requestId = (JSON.parse(queued.body) as { requestId: string }).requestId;

    const accepted = await performRequest(port, "POST", `/v1/requests/${requestId}/ack`, {
      token: mac.deviceToken,
      body: { status: "accepted" },
    });
    assert.equal(accepted.statusCode, 200);
    assert.equal((JSON.parse(accepted.body) as { status: string; acknowledgedAt?: string }).status, "accepted");

    const completed = await performRequest(port, "POST", `/v1/requests/${requestId}/ack`, {
      token: mac.deviceToken,
      body: { status: "completed", result: { refreshed: true } },
    });
    assert.equal(completed.statusCode, 200);
    const parsed = JSON.parse(completed.body) as { status: string; completedAt?: string; result?: { refreshed?: boolean } };
    assert.equal(parsed.status, "completed");
    assert.equal(parsed.result?.refreshed, true);
    assert.ok(parsed.completedAt);
  } finally {
    await close();
  }
});

test("heartbeat updates presence", async () => {
  const { port, close, store } = await bootStore();
  try {
    const mac = store.registerMac("user-1", "MacBook");
    const response = await performRequest(port, "POST", "/v1/heartbeat", {
      token: mac.deviceToken,
      body: { state: "busy", activeSessionId: "session-1" },
    });
    assert.equal(response.statusCode, 200);
    const presence = store.getPresence(mac.deviceId);
    assert.equal(presence?.state, "busy");
    assert.equal(presence?.activeSessionId, "session-1");

    const listed = await performRequest(port, "GET", "/v1/presence", {
      token: mac.deviceToken,
    });
    const parsed = JSON.parse(listed.body) as { presence: Array<{ deviceId: string; state: string }> };
    assert.equal(parsed.presence.length, 1);
    assert.equal(parsed.presence[0]?.deviceId, mac.deviceId);
  } finally {
    await close();
  }
});

test("malformed body yields 400", async () => {
  const { port, close, store } = await bootStore();
  try {
    const mac = store.registerMac("user-1", "MacBook");
    const response = await performRequest(port, "POST", "/v1/plugin-events", {
      token: mac.deviceToken,
      body: "not an object" as unknown as Record<string, unknown>,
    });
    assert.equal(response.statusCode, 400);
  } finally {
    await close();
  }
});

test("unknown route yields 404", async () => {
  const { port, close } = await bootStore();
  try {
    const response = await performRequest(port, "GET", "/no-such-path");
    assert.equal(response.statusCode, 404);
  } finally {
    await close();
  }
});
