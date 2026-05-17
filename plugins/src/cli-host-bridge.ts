import http from "node:http";

import type { BridgeDecision, PluginEventEnvelope } from "./types.js";

export type RelayClient = {
  ingestEvent(event: PluginEventEnvelope): Promise<void>;
  waitForDecision(event: PluginEventEnvelope, timeoutMs: number): Promise<BridgeDecision | null>;
};

export type CLIHostBridgeOptions = {
  relayClient: RelayClient;
  approvalTimeoutMs?: number;
};

export class CLIHostBridge {
  private readonly relayClient: RelayClient;
  private readonly approvalTimeoutMs: number;

  constructor(options: CLIHostBridgeOptions) {
    this.relayClient = options.relayClient;
    this.approvalTimeoutMs = options.approvalTimeoutMs ?? 110_000;
  }

  async handlePluginEvent(event: PluginEventEnvelope): Promise<BridgeDecision | null> {
    await this.relayClient.ingestEvent(event);
    if (event.event !== "approval.requested") return null;
    return this.relayClient.waitForDecision(event, this.approvalTimeoutMs);
  }
}

export function createCLIHostBridgeServer(bridge: CLIHostBridge): http.Server {
  return http.createServer((request, response) => {
    if (request.method !== "POST" || request.url !== "/v1/plugin-events") {
      response.writeHead(404).end();
      return;
    }

    readBody(request)
      .then((body) => bridge.handlePluginEvent(JSON.parse(body) as PluginEventEnvelope))
      .then((decision) => {
        if (!decision) {
          response.writeHead(204).end();
          return;
        }
        const payload = JSON.stringify(decision);
        response.writeHead(200, {
          "content-type": "application/json",
          "content-length": Buffer.byteLength(payload),
        });
        response.end(payload);
      })
      .catch(() => {
        response.writeHead(400).end();
      });
  });
}

function readBody(request: http.IncomingMessage): Promise<string> {
  return new Promise((resolve, reject) => {
    const chunks: Buffer[] = [];
    request.on("data", (chunk: Buffer) => chunks.push(chunk));
    request.on("end", () => resolve(Buffer.concat(chunks).toString("utf8")));
    request.on("error", reject);
  });
}
