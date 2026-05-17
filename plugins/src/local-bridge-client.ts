import http from "node:http";

import { withTimeout } from "./timeout.js";
import type { BridgeClient, BridgeDecision, PluginEventEnvelope } from "./types.js";

export type LocalBridgeClientOptions = {
  port?: number;
  host?: string;
};

export class LocalBridgeClient implements BridgeClient {
  private readonly host: string;
  private readonly port: number;

  constructor(options: LocalBridgeClientOptions = {}) {
    this.host = options.host ?? "127.0.0.1";
    this.port = options.port ?? 7474;
  }

  async send(event: PluginEventEnvelope, timeoutMs: number): Promise<BridgeDecision | null> {
    return withTimeout(this.post(event), timeoutMs, null);
  }

  private post(event: PluginEventEnvelope): Promise<BridgeDecision | null> {
    const body = JSON.stringify(event);
    return new Promise((resolve) => {
      const request = http.request(
        {
          hostname: this.host,
          port: this.port,
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
      request.on("error", () => resolve(null));
      request.end(body);
    });
  }
}
