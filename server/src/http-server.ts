// Plain Node `http` HTTP wrapper around `RelayStore`. Mirrors the Swift
// HTTP server style in
// apps/apple/Sources/KiriFriendsMacBuddyKit/HTTP/HTTPServer.swift so the
// behaviour stays familiar across languages. Authentication piggybacks
// on `RelayStore.authenticate`; every protected route expects an
// `Authorization: Bearer <token>` header.

import { createServer, type IncomingMessage, type Server, type ServerResponse } from "node:http";

import type { RelayStore } from "./relay-store.js";
import type { DeviceRecord, DeviceRole } from "./types.js";

export type HTTPServerOptions = {
  store: RelayStore;
  port?: number;
  host?: string;
};

export type HTTPServerHandle = {
  server: Server;
  port: number;
  close: () => Promise<void>;
};

const MAX_BODY_BYTES = 1 * 1024 * 1024;

export function createHTTPServer(options: HTTPServerOptions): Server {
  const { store } = options;

  return createServer(async (request, response) => {
    try {
      await route(store, request, response);
    } catch (error) {
      writeError(response, 500, "internal_error", error instanceof Error ? error.message : "unexpected error");
    }
  });
}

export async function listenHTTPServer(options: HTTPServerOptions): Promise<HTTPServerHandle> {
  const server = createHTTPServer(options);
  const port = options.port ?? 0;
  const host = options.host ?? "127.0.0.1";

  await new Promise<void>((resolve, reject) => {
    server.once("error", reject);
    server.listen(port, host, () => {
      server.off("error", reject);
      resolve();
    });
  });

  const address = server.address();
  const boundPort = typeof address === "object" && address ? address.port : port;
  return {
    server,
    port: boundPort,
    close: () => new Promise<void>((resolve, reject) => {
      server.close((error) => (error ? reject(error) : resolve()));
    }),
  };
}

async function route(
  store: RelayStore,
  request: IncomingMessage,
  response: ServerResponse,
): Promise<void> {
  const url = parseURL(request.url ?? "/");
  const key = `${request.method ?? "GET"} ${url.path}`;

  switch (key) {
    case "GET /healthz":
      writeJSON(response, 200, { status: "ok" });
      return;
    case "POST /v1/plugin-events":
      await handleIngestEvent(store, request, response, url);
      return;
    case "GET /v1/events":
      handleListEvents(store, request, response, url);
      return;
    case "POST /v1/requests":
      await handleEnqueueRequest(store, request, response, url);
      return;
    case "GET /v1/requests/pending":
      handleListPending(store, request, response, url);
      return;
    case "POST /v1/heartbeat":
      await handleHeartbeat(store, request, response, url);
      return;
    default:
      writeError(response, 404, "not_found", `no route for ${key}`);
  }
}

async function handleIngestEvent(
  store: RelayStore,
  request: IncomingMessage,
  response: ServerResponse,
  _url: ParsedURL,
): Promise<void> {
  const auth = authenticate(store, request, ["mac_bridge", "cli_host_bridge"]);
  if (!auth.ok) {
    writeError(response, auth.status, auth.code, auth.message);
    return;
  }
  const device = auth.device;

  const body = await readBody(request);
  if (!body) {
    writeError(response, 400, "invalid_request", "empty body");
    return;
  }

  const envelope = safeParse(body);
  if (!envelope || typeof envelope !== "object") {
    writeError(response, 400, "invalid_request", "body must be JSON object");
    return;
  }

  const eventName = (envelope as { event?: unknown }).event;
  if (typeof eventName !== "string" || eventName.length === 0) {
    writeError(response, 400, "invalid_request", "event field is required");
    return;
  }

  const sessionId = (envelope as { sessionId?: unknown }).sessionId;
  const payload = (envelope as { payload?: unknown }).payload;
  if (payload !== undefined && (payload === null || typeof payload !== "object")) {
    writeError(response, 400, "invalid_request", "payload must be an object");
    return;
  }

  try {
    const ingestInput: Parameters<RelayStore["ingestEvent"]>[0] = {
      userId: device.userId,
      sourceDeviceId: device.id,
      event: eventName,
      payload: (payload as Record<string, unknown> | undefined) ?? {},
    };
    if (typeof sessionId === "string") ingestInput.sessionId = sessionId;
    const stored = store.ingestEvent(ingestInput);
    writeJSON(response, 201, stored);
  } catch (error) {
    writeError(response, 403, "not_authorized", error instanceof Error ? error.message : "ingest rejected");
  }
}

function handleListEvents(
  store: RelayStore,
  request: IncomingMessage,
  response: ServerResponse,
  url: ParsedURL,
): void {
  const auth = authenticate(store, request, ["iphone_companion"]);
  if (!auth.ok) {
    writeError(response, auth.status, auth.code, auth.message);
    return;
  }
  const userId = url.query.get("userId") ?? auth.device.userId;
  if (userId !== auth.device.userId) {
    writeError(response, 403, "not_authorized", "userId mismatch");
    return;
  }
  const since = url.query.get("since");
  let events = store.listEventsForUser(userId);
  if (since) {
    const index = events.findIndex((event) => event.eventId === since);
    if (index >= 0) {
      events = events.slice(index + 1);
    }
  }
  writeJSON(response, 200, { events });
}

async function handleEnqueueRequest(
  store: RelayStore,
  request: IncomingMessage,
  response: ServerResponse,
  _url: ParsedURL,
): Promise<void> {
  const auth = authenticate(store, request, ["iphone_companion"]);
  if (!auth.ok) {
    writeError(response, auth.status, auth.code, auth.message);
    return;
  }

  const body = await readBody(request);
  if (!body) {
    writeError(response, 400, "invalid_request", "empty body");
    return;
  }
  const envelope = safeParse(body);
  if (!envelope || typeof envelope !== "object") {
    writeError(response, 400, "invalid_request", "body must be JSON object");
    return;
  }

  const targetDeviceId = (envelope as { targetDeviceId?: unknown }).targetDeviceId;
  const kind = (envelope as { kind?: unknown }).kind;
  const expiresAt = (envelope as { expiresAt?: unknown }).expiresAt;
  const idempotencyKey = (envelope as { idempotencyKey?: unknown }).idempotencyKey;
  const payload = (envelope as { payload?: unknown }).payload ?? {};
  const sessionId = (envelope as { sessionId?: unknown }).sessionId;

  if (typeof targetDeviceId !== "string" || typeof kind !== "string" ||
      typeof expiresAt !== "string" || typeof idempotencyKey !== "string") {
    writeError(response, 400, "invalid_request", "missing required field");
    return;
  }

  try {
    const enqueueInput: Parameters<RelayStore["enqueueRequest"]>[0] = {
      userId: auth.device.userId,
      targetDeviceId,
      kind,
      expiresAt,
      idempotencyKey,
      payload: payload as Record<string, unknown>,
    };
    if (typeof sessionId === "string") enqueueInput.sessionId = sessionId;
    const stored = store.enqueueRequest(enqueueInput);
    writeJSON(response, 202, stored);
  } catch (error) {
    writeError(response, 400, "invalid_request", error instanceof Error ? error.message : "enqueue rejected");
  }
}

function handleListPending(
  store: RelayStore,
  request: IncomingMessage,
  response: ServerResponse,
  url: ParsedURL,
): void {
  const auth = authenticate(store, request, ["mac_bridge", "cli_host_bridge"]);
  if (!auth.ok) {
    writeError(response, auth.status, auth.code, auth.message);
    return;
  }
  const deviceId = url.query.get("deviceId") ?? auth.device.id;
  if (deviceId !== auth.device.id) {
    writeError(response, 403, "not_authorized", "deviceId mismatch");
    return;
  }
  writeJSON(response, 200, { requests: store.listPendingRequests(deviceId) });
}

async function handleHeartbeat(
  store: RelayStore,
  request: IncomingMessage,
  response: ServerResponse,
  _url: ParsedURL,
): Promise<void> {
  const auth = authenticate(store, request);
  if (!auth.ok) {
    writeError(response, auth.status, auth.code, auth.message);
    return;
  }

  const body = await readBody(request);
  const envelope = body ? safeParse(body) : {};
  if (!envelope || typeof envelope !== "object") {
    writeError(response, 400, "invalid_request", "body must be JSON object");
    return;
  }
  const state = (envelope as { state?: unknown }).state;
  const activeSessionId = (envelope as { activeSessionId?: unknown }).activeSessionId;
  if (state !== "online" && state !== "idle" && state !== "busy" &&
      state !== "waiting" && state !== "offline") {
    writeError(response, 400, "invalid_request", "state must be a presence value");
    return;
  }
  const record = store.heartbeat(
    auth.device.id,
    state,
    typeof activeSessionId === "string" ? activeSessionId : undefined,
  );
  writeJSON(response, 200, record);
}

// MARK: - helpers

type AuthResult =
  | { ok: true; device: DeviceRecord }
  | { ok: false; status: number; code: string; message: string };

function authenticate(
  store: RelayStore,
  request: IncomingMessage,
  allowedRoles?: DeviceRole[],
): AuthResult {
  const header = request.headers.authorization;
  if (!header || !header.startsWith("Bearer ")) {
    return { ok: false, status: 401, code: "not_authenticated", message: "missing bearer token" };
  }
  const token = header.slice("Bearer ".length).trim();
  const device = store.authenticate(token);
  if (!device) {
    return { ok: false, status: 401, code: "not_authenticated", message: "invalid token" };
  }
  if (allowedRoles && !allowedRoles.includes(device.role)) {
    return { ok: false, status: 403, code: "not_authorized", message: `role ${device.role} cannot use this route` };
  }
  return { ok: true, device };
}

type ParsedURL = { path: string; query: URLSearchParams };

function parseURL(rawTarget: string): ParsedURL {
  const safeTarget = rawTarget.startsWith("/") ? rawTarget : `/${rawTarget}`;
  const parsed = new URL(safeTarget, "http://placeholder");
  return { path: parsed.pathname, query: parsed.searchParams };
}

function readBody(request: IncomingMessage): Promise<string | null> {
  return new Promise((resolve, reject) => {
    const chunks: Buffer[] = [];
    let total = 0;
    request.on("data", (chunk: Buffer) => {
      total += chunk.length;
      if (total > MAX_BODY_BYTES) {
        request.destroy(new Error("payload_too_large"));
        return;
      }
      chunks.push(chunk);
    });
    request.on("end", () => {
      if (chunks.length === 0) {
        resolve(null);
        return;
      }
      resolve(Buffer.concat(chunks).toString("utf8"));
    });
    request.on("error", reject);
  });
}

function safeParse(body: string): unknown {
  try {
    return JSON.parse(body);
  } catch {
    return null;
  }
}

function writeJSON(response: ServerResponse, status: number, value: unknown): void {
  const body = JSON.stringify(value);
  response.writeHead(status, {
    "Content-Type": "application/json; charset=utf-8",
    "Content-Length": Buffer.byteLength(body),
    "Cache-Control": "no-store",
  });
  response.end(body);
}

function writeError(response: ServerResponse, status: number, code: string, message: string): void {
  writeJSON(response, status, {
    ok: false,
    error: { code, message, retryable: status >= 500 },
  });
}
