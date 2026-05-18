import { fileURLToPath } from "node:url";
import type { Writable } from "node:stream";

import {
  buildDebugScenarioEvents,
  debugScenarioDefinitions,
  getDebugScenario,
  isDebugScenarioName,
  type DebugScenarioEvent,
  type DebugScenarioName,
} from "./debug-scenarios.js";

type CLIEnvironment = Partial<Pick<NodeJS.ProcessEnv, "KIRI_RELAY_URL">>;

export type DebugCLIOptions = {
  env?: CLIEnvironment;
  stdout?: Writable;
  stderr?: Writable;
};

type ParsedArgs = {
  command: string;
  positionals: string[];
  flags: Map<string, string | true>;
};

type DeviceRegistrationResponse = {
  deviceId: string;
  deviceToken: string;
};

type MacRegistrationResponse = DeviceRegistrationResponse & {
  pairingCode: string;
  pairingExpiresAt: string;
};

type PairingResponse = {
  id: string;
  userId: string;
  iphoneDeviceId: string;
  macDeviceId: string;
  createdAt: string;
};

type EventResponse = {
  eventId: string;
  event: string;
  sessionId?: string;
};

type RequestResponse = {
  requestId: string;
  kind: string;
  status: string;
};

type SeedResult = {
  relayURL: string;
  userId: string;
  iphone: DeviceRegistrationResponse;
  mac: MacRegistrationResponse;
  pairing: PairingResponse;
  scenario: DebugScenarioName;
  events: EventResponse[];
  request: RequestResponse | null;
  environment: Record<string, string>;
};

class RelayDebugClient {
  constructor(private readonly baseURL: string) {}

  async get<T>(path: string, token?: string): Promise<T> {
    return await this.request<T>("GET", path, token);
  }

  async post<T>(path: string, body: unknown, token?: string): Promise<T> {
    return await this.request<T>("POST", path, token, body);
  }

  private async request<T>(method: string, path: string, token?: string, body?: unknown): Promise<T> {
    const headers: Record<string, string> = {};
    if (token) headers.Authorization = `Bearer ${token}`;
    let payload: string | undefined;
    if (body !== undefined) {
      payload = JSON.stringify(body);
      headers["Content-Type"] = "application/json";
    }

    const requestInit: RequestInit = {
      method,
      headers,
    };
    if (payload !== undefined) requestInit.body = payload;

    const response = await fetch(new URL(path, this.baseURL), requestInit);
    const text = await response.text();
    const parsed = text.length > 0 ? parseJSON(text) : null;
    if (!response.ok) {
      throw new Error(`${method} ${path} failed with ${response.status}: ${text}`);
    }
    return parsed as T;
  }
}

export async function runDebugCLI(args: string[], options: DebugCLIOptions = {}): Promise<number> {
  const stdout = options.stdout ?? process.stdout;
  const stderr = options.stderr ?? process.stderr;
  const env = options.env ?? process.env;

  try {
    const parsed = parseArgs(args);
    if (parsed.command === "help" || parsed.flags.has("help")) {
      write(stdout, usage());
      return 0;
    }
    if (parsed.command === "list") {
      write(stdout, `${JSON.stringify({ scenarios: debugScenarioDefinitions }, null, 2)}\n`);
      return 0;
    }

    const relayURL = stringFlag(parsed, "url") ?? env.KIRI_RELAY_URL ?? "http://127.0.0.1:8585";
    const client = new RelayDebugClient(relayURL);

    switch (parsed.command) {
      case "seed": {
        const result = await seed(client, relayURL, parsed);
        writeResult(stdout, parsed, result, formatSeedResult(result));
        return 0;
      }
      case "scenario": {
        const result = await injectScenario(client, parsed);
        writeResult(stdout, parsed, result, `Injected ${result.events.length} event(s) for ${result.scenario}.\n`);
        return 0;
      }
      case "request": {
        const result = await enqueueDebugRequest(client, parsed);
        writeResult(stdout, parsed, result, `Queued request ${result.requestId} (${result.kind}).\n`);
        return 0;
      }
      case "ack": {
        const result = await ackDebugRequest(client, parsed);
        writeResult(stdout, parsed, result, `Acknowledged request ${result.requestId} as ${result.status}.\n`);
        return 0;
      }
      default:
        write(stderr, `Unknown command: ${parsed.command}\n\n${usage()}`);
        return 1;
    }
  } catch (error) {
    write(stderr, `${error instanceof Error ? error.message : "debug command failed"}\n`);
    return 1;
  }
}

async function seed(client: RelayDebugClient, relayURL: string, args: ParsedArgs): Promise<SeedResult> {
  const scenario = scenarioFlag(args);
  const definition = getDebugScenario(scenario);
  const userId = stringFlag(args, "user-id") ?? `debug-${Date.now()}`;
  const iphoneName = stringFlag(args, "iphone-name") ?? "Debug iPhone";
  const macName = stringFlag(args, "mac-name") ?? "Debug Mac Bridge";

  const iphone = await client.post<DeviceRegistrationResponse>("/v1/devices/iphone", {
    userId,
    name: iphoneName,
  });
  const mac = await client.post<MacRegistrationResponse>("/v1/devices/mac", {
    userId,
    name: macName,
  });
  const pairing = await client.post<PairingResponse>(
    "/v1/pairings/approve",
    { pairingCode: mac.pairingCode },
    iphone.deviceToken,
  );

  const events = await postScenarioEvents(client, mac.deviceToken, scenario, args);
  const lastEvent = events.at(-1);
  await client.post(
    "/v1/heartbeat",
    {
      state: stringFlag(args, "presence") ?? definition.defaultPresence,
      activeSessionId: lastEvent?.sessionId ?? `debug-${scenario}`,
    },
    mac.deviceToken,
  );

  const request = boolFlag(args, "no-request")
    ? null
    : await createRequest(client, args, iphone.deviceToken, mac.deviceId, defaultRequestKind(scenario), `debug-${scenario}`);

  return {
    relayURL,
    userId,
    iphone,
    mac,
    pairing,
    scenario,
    events,
    request,
    environment: {
      KIRI_RELAY_URL: relayURL,
      KIRI_DEVICE_TOKEN: iphone.deviceToken,
      KIRI_USER_ID: userId,
      KIRI_MAC_DEVICE_ID: mac.deviceId,
    },
  };
}

async function injectScenario(
  client: RelayDebugClient,
  args: ParsedArgs,
): Promise<{ scenario: DebugScenarioName; events: EventResponse[] }> {
  const scenario = positionalScenario(args, 0);
  const macToken = requiredFlag(args, "mac-token");
  const events = await postScenarioEvents(client, macToken, scenario, args);
  await client.post(
    "/v1/heartbeat",
    {
      state: stringFlag(args, "presence") ?? getDebugScenario(scenario).defaultPresence,
      activeSessionId: events.at(-1)?.sessionId ?? `debug-${scenario}`,
    },
    macToken,
  );
  return { scenario, events };
}

async function enqueueDebugRequest(client: RelayDebugClient, args: ParsedArgs): Promise<RequestResponse> {
  const kind = requiredPositional(args, 0, "request kind");
  const iphoneToken = requiredFlag(args, "iphone-token");
  const macDeviceId = requiredFlag(args, "mac-device-id");
  return await createRequest(client, args, iphoneToken, macDeviceId, kind, stringFlag(args, "session-id") ?? "debug-request");
}

async function ackDebugRequest(client: RelayDebugClient, args: ParsedArgs): Promise<RequestResponse> {
  const requestId = requiredPositional(args, 0, "request id");
  const macToken = requiredFlag(args, "mac-token");
  const status = stringFlag(args, "status") ?? "completed";
  const body: Record<string, unknown> = { status };
  const resultJSON = stringFlag(args, "result-json");
  if (resultJSON) body.result = parseJSON(resultJSON);
  const error = stringFlag(args, "error");
  if (error) body.error = error;
  return await client.post<RequestResponse>(`/v1/requests/${encodeURIComponent(requestId)}/ack`, body, macToken);
}

async function postScenarioEvents(
  client: RelayDebugClient,
  macToken: string,
  scenario: DebugScenarioName,
  args: ParsedArgs,
): Promise<EventResponse[]> {
  const events = buildDebugScenarioEvents(scenario, {
    cwd: stringFlag(args, "cwd") ?? "/Users/debug/kiri-friends",
    sessionId: stringFlag(args, "session-id") ?? `debug-${scenario}`,
    tool: stringFlag(args, "tool") ?? "codex",
  });
  const responses: EventResponse[] = [];
  for (const envelope of events) {
    responses.push(await client.post<EventResponse>("/v1/plugin-events", envelope, macToken));
  }
  return responses;
}

async function createRequest(
  client: RelayDebugClient,
  args: ParsedArgs,
  iphoneToken: string,
  macDeviceId: string,
  kind: string,
  fallbackSessionId: string,
): Promise<RequestResponse> {
  const sessionId = stringFlag(args, "session-id") ?? fallbackSessionId;
  const payload = requestPayload(kind, sessionId, args);
  return await client.post<RequestResponse>(
    "/v1/requests",
    {
      targetDeviceId: macDeviceId,
      sessionId,
      kind,
      expiresAt: new Date(Date.now() + integerFlag(args, "expires-in-seconds", 90) * 1000).toISOString(),
      idempotencyKey: stringFlag(args, "idempotency-key") ?? `debug-${kind}-${Date.now()}`,
      payload,
    },
    iphoneToken,
  );
}

function requestPayload(kind: string, sessionId: string, args: ParsedArgs): Record<string, unknown> {
  const payloadJSON = stringFlag(args, "payload-json");
  if (payloadJSON) return parseJSON(payloadJSON) as Record<string, unknown>;

  if (kind === "approval.allow") return { sessionId, decision: "allow", tool: stringFlag(args, "tool") ?? "codex" };
  if (kind === "approval.deny") return { sessionId, decision: "deny", tool: stringFlag(args, "tool") ?? "codex" };
  if (kind === "prompt.sendQuick") return { sessionId, text: stringFlag(args, "text") ?? "Looks good.", tool: stringFlag(args, "tool") ?? "codex" };
  if (kind === "task.stop") return { sessionId, tool: stringFlag(args, "tool") ?? "codex" };
  return { sessionId, source: "debug-cli" };
}

function defaultRequestKind(scenario: DebugScenarioName): string {
  if (scenario === "waiting-input") return "prompt.sendQuick";
  if (scenario === "running-tool") return "status.refresh";
  return "approval.allow";
}

function scenarioFlag(args: ParsedArgs): DebugScenarioName {
  const raw = stringFlag(args, "scenario") ?? "approval-shell";
  if (!isDebugScenarioName(raw)) throw new Error(`unknown scenario: ${raw}`);
  return raw;
}

function positionalScenario(args: ParsedArgs, index: number): DebugScenarioName {
  const raw = requiredPositional(args, index, "scenario");
  if (!isDebugScenarioName(raw)) throw new Error(`unknown scenario: ${raw}`);
  return raw;
}

function parseArgs(args: string[]): ParsedArgs {
  const [command = "help", ...rest] = args;
  const flags = new Map<string, string | true>();
  const positionals: string[] = [];

  for (let index = 0; index < rest.length; index += 1) {
    const token = rest[index];
    if (!token) continue;
    if (!token.startsWith("--")) {
      positionals.push(token);
      continue;
    }

    const withoutPrefix = token.slice(2);
    const equalsIndex = withoutPrefix.indexOf("=");
    if (equalsIndex >= 0) {
      flags.set(withoutPrefix.slice(0, equalsIndex), withoutPrefix.slice(equalsIndex + 1));
      continue;
    }

    const next = rest[index + 1];
    if (next && !next.startsWith("--")) {
      flags.set(withoutPrefix, next);
      index += 1;
    } else {
      flags.set(withoutPrefix, true);
    }
  }

  return { command, positionals, flags };
}

function stringFlag(args: ParsedArgs, name: string): string | undefined {
  const value = args.flags.get(name);
  return typeof value === "string" ? value : undefined;
}

function boolFlag(args: ParsedArgs, name: string): boolean {
  return args.flags.get(name) === true;
}

function integerFlag(args: ParsedArgs, name: string, fallback: number): number {
  const value = stringFlag(args, name);
  if (!value) return fallback;
  const parsed = Number.parseInt(value, 10);
  if (!Number.isFinite(parsed) || parsed <= 0) throw new Error(`--${name} must be a positive integer`);
  return parsed;
}

function requiredFlag(args: ParsedArgs, name: string): string {
  const value = stringFlag(args, name);
  if (!value) throw new Error(`--${name} is required`);
  return value;
}

function requiredPositional(args: ParsedArgs, index: number, label: string): string {
  const value = args.positionals[index];
  if (!value) throw new Error(`${label} is required`);
  return value;
}

function writeResult(stdout: Writable, args: ParsedArgs, value: unknown, human: string): void {
  if (boolFlag(args, "json")) {
    write(stdout, `${JSON.stringify(value, null, 2)}\n`);
    return;
  }
  write(stdout, human);
}

function formatSeedResult(result: SeedResult): string {
  return [
    `Seeded debug relay environment for ${result.userId}.`,
    `Scenario: ${result.scenario}`,
    `iPhone device: ${result.iphone.deviceId}`,
    `Mac device: ${result.mac.deviceId}`,
    result.request ? `Queued request: ${result.request.requestId} (${result.request.kind})` : "Queued request: skipped",
    "",
    "Use these values for the iPhone companion:",
    `KIRI_RELAY_URL=${result.environment.KIRI_RELAY_URL}`,
    `KIRI_DEVICE_TOKEN=${result.environment.KIRI_DEVICE_TOKEN}`,
    `KIRI_USER_ID=${result.environment.KIRI_USER_ID}`,
    `KIRI_MAC_DEVICE_ID=${result.environment.KIRI_MAC_DEVICE_ID}`,
    "",
  ].join("\n");
}

function usage(): string {
  return `Kiri Relay debug CLI

Usage:
  npm run debug -- seed [--scenario approval-shell] [--json]
  npm run debug -- scenario <name> --mac-token <token>
  npm run debug -- request <kind> --iphone-token <token> --mac-device-id <id>
  npm run debug -- ack <requestId> --mac-token <token> [--status completed]
  npm run debug -- list

Options:
  --url <url>                 Relay URL. Defaults to KIRI_RELAY_URL or http://127.0.0.1:8585.
  --user-id <id>              User id for seed. Defaults to debug-<timestamp>.
  --session-id <id>           Session id for scenario/request payloads.
  --tool <name>               CLI tool id for single-agent scenarios. Defaults to codex.
  --cwd <path>                Working directory shown in debug events.
  --no-request                Seed devices/events without queueing a debug request.
  --payload-json <json>       Request payload override.
  --result-json <json>        Ack result override.
  --json                      Print machine-readable JSON.

Scenarios:
${debugScenarioDefinitions.map((scenario) => `  ${scenario.name.padEnd(16)} ${scenario.description}`).join("\n")}
`;
}

function parseJSON(value: string): unknown {
  try {
    return JSON.parse(value);
  } catch {
    throw new Error(`invalid JSON: ${value}`);
  }
}

function write(stream: Writable, value: string): void {
  stream.write(value);
}

const entryPath = process.argv[1] ? fileURLToPath(import.meta.url) === process.argv[1] : false;
if (entryPath) {
  process.exitCode = await runDebugCLI(process.argv.slice(2));
}

export type { SeedResult, RequestResponse, EventResponse };
