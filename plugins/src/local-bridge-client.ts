import { readFile } from "node:fs/promises";
import http from "node:http";

import { withTimeout } from "./timeout.js";
import type { BridgeClient, BridgeDecision, PluginEventEnvelope } from "./types.js";

export type LocalBridgeClientOptions = {
  port?: number;
  host?: string;
  runtimeConfigPath?: string;
  portCandidates?: number[];
  env?: NodeJS.ProcessEnv;
};

export type BridgeRuntimeConfig = {
  host?: string;
  port?: number;
  ports?: number[];
};

export type BridgeTarget = {
  host: string;
  port: number;
};

const DEFAULT_HOST = "127.0.0.1";
const DEFAULT_PORT = 7474;
const DEFAULT_PORT_CANDIDATES = [7474, 7475, 7476, 7477, 7478];

export class LocalBridgeClient implements BridgeClient {
  private readonly host: string;
  private readonly explicitPort: number | undefined;
  private readonly runtimeConfigPath: string | undefined;
  private readonly portCandidates: number[];
  private readonly env: NodeJS.ProcessEnv;

  constructor(options: LocalBridgeClientOptions = {}) {
    this.host = options.host ?? DEFAULT_HOST;
    this.explicitPort = options.port;
    this.runtimeConfigPath = options.runtimeConfigPath;
    this.portCandidates = options.portCandidates ?? DEFAULT_PORT_CANDIDATES;
    this.env = options.env ?? process.env;
  }

  async send(event: PluginEventEnvelope, timeoutMs: number): Promise<BridgeDecision | null> {
    const targets = await this.targets();
    return withTimeout(this.postFirstAvailable(event, targets), timeoutMs, null);
  }

  private async targets(): Promise<BridgeTarget[]> {
    const runtime = await this.loadRuntimeConfig();
    const input: ResolveBridgeTargetsInput = {
      host: this.host,
      runtime,
      env: this.env,
      portCandidates: this.portCandidates,
    };
    if (this.explicitPort !== undefined) input.explicitPort = this.explicitPort;
    return resolveBridgeTargets(input);
  }

  private async loadRuntimeConfig(): Promise<BridgeRuntimeConfig | null> {
    if (!this.runtimeConfigPath) return null;
    try {
      const text = await readFile(this.runtimeConfigPath, "utf8");
      const parsed = JSON.parse(text) as BridgeRuntimeConfig;
      return parsed && typeof parsed === "object" ? parsed : null;
    } catch {
      return null;
    }
  }

  private async postFirstAvailable(event: PluginEventEnvelope, targets: BridgeTarget[]): Promise<BridgeDecision | null> {
    for (const target of targets) {
      const decision = await this.post(event, target);
      if (decision !== undefined) return decision;
    }
    return null;
  }

  private post(event: PluginEventEnvelope, target: BridgeTarget): Promise<BridgeDecision | null | undefined> {
    const body = JSON.stringify(event);
    return new Promise((resolve) => {
      const request = http.request(
        {
          hostname: target.host,
          port: target.port,
          path: "/v1/plugin-events",
          method: "POST",
          headers: {
            "content-type": "application/json",
            "content-length": Buffer.byteLength(body),
          },
        },
        (response) => {
          const chunks: Buffer[] = [];
          response.on("data", (chunk: Buffer) => chunks.push(chunk));
          response.on("end", () => {
            if (chunks.length === 0) {
              resolve(null);
              return;
            }
            try {
              resolve(JSON.parse(Buffer.concat(chunks).toString("utf8")) as BridgeDecision);
            } catch {
              resolve(null);
            }
          });
        },
      );
      request.on("error", () => resolve(undefined));
      request.end(body);
    });
  }
}

type ResolveBridgeTargetsInput = {
  host?: string;
  explicitPort?: number;
  runtime?: BridgeRuntimeConfig | null;
  env?: NodeJS.ProcessEnv;
  portCandidates?: number[];
};

export function resolveBridgeTargets(input: ResolveBridgeTargetsInput): BridgeTarget[] {
  const host = input.runtime?.host ?? input.host ?? DEFAULT_HOST;
  const ports = [
    input.explicitPort,
    parsePort(input.env?.KIRI_BRIDGE_PORT),
    input.runtime?.port,
    ...(input.runtime?.ports ?? []),
    ...(input.portCandidates ?? DEFAULT_PORT_CANDIDATES),
    DEFAULT_PORT,
  ].filter((port): port is number => typeof port === "number" && Number.isInteger(port) && port > 0);

  const seen = new Set<number>();
  return ports
    .filter((port) => {
      if (seen.has(port)) return false;
      seen.add(port);
      return true;
    })
    .map((port) => ({ host, port }));
}

function parsePort(value: string | undefined): number | undefined {
  if (!value) return undefined;
  const parsed = Number(value);
  return Number.isInteger(parsed) && parsed > 0 ? parsed : undefined;
}
