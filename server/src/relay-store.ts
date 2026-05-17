import { randomUUID } from "node:crypto";

import { hashToken, signDeviceToken, verifyDeviceToken } from "./token.js";
import type {
  DeviceRecord,
  DeviceRegistrationResult,
  DeviceRole,
  MacRegistrationResult,
  PairingCodeRecord,
  PairingRecord,
  PresenceRecord,
  PresenceState,
  RelayRequest,
  RequestStatus,
} from "./types.js";

export type RelayStoreOptions = {
  tokenSecret: string;
  now?: () => Date;
};

export class RelayStore {
  private readonly tokenSecret: string;
  private readonly now: () => Date;
  private readonly devices = new Map<string, DeviceRecord>();
  private readonly pairingCodes = new Map<string, PairingCodeRecord>();
  private readonly pairings = new Map<string, PairingRecord>();
  private readonly presence = new Map<string, PresenceRecord>();
  private readonly requests = new Map<string, RelayRequest>();
  private readonly requestByIdempotency = new Map<string, string>();

  constructor(options: RelayStoreOptions) {
    this.tokenSecret = options.tokenSecret;
    this.now = options.now ?? (() => new Date());
  }

  registerIPhone(userId: string, deviceName: string): DeviceRegistrationResult {
    return this.registerDevice(userId, "iphone_companion", deviceName);
  }

  registerMac(
    userId: string,
    deviceName: string,
    pairingTtlMs = 5 * 60 * 1000,
  ): MacRegistrationResult {
    const device = this.registerDevice(userId, "mac_bridge", deviceName);
    const pairingCode = this.createPairingCode(userId, device.deviceId, pairingTtlMs);
    const codeRecord = this.pairingCodes.get(pairingCode);
    if (!codeRecord) throw new Error("pairing code was not created");

    return {
      ...device,
      pairingCode,
      pairingExpiresAt: codeRecord.expiresAt,
    };
  }

  approvePairing(userId: string, iphoneDeviceId: string, pairingCode: string): PairingRecord {
    const iphone = this.requireDevice(iphoneDeviceId);
    if (iphone.userId !== userId || iphone.role !== "iphone_companion") {
      throw new Error("invalid iPhone companion for pairing");
    }

    const code = this.pairingCodes.get(pairingCode);
    if (!code || code.userId !== userId) {
      throw new Error("pairing code not found");
    }
    if (code.usedAt) {
      throw new Error("pairing code already used");
    }
    if (Date.parse(code.expiresAt) <= this.now().getTime()) {
      throw new Error("pairing code expired");
    }

    code.usedAt = this.now().toISOString();
    const pairing: PairingRecord = {
      id: randomUUID(),
      userId,
      iphoneDeviceId,
      macDeviceId: code.macDeviceId,
      createdAt: this.now().toISOString(),
    };
    this.pairings.set(pairing.id, pairing);
    return pairing;
  }

  authenticate(token: string): DeviceRecord | null {
    const claims = verifyDeviceToken(token, this.tokenSecret);
    if (!claims) return null;

    const device = this.devices.get(claims.deviceId);
    if (!device || device.revokedAt) return null;
    if (device.userId !== claims.userId || device.role !== claims.role) return null;
    if (device.tokenHash !== hashToken(token, this.tokenSecret)) return null;
    return device;
  }

  heartbeat(deviceId: string, state: PresenceState, activeSessionId?: string): PresenceRecord {
    this.requireDevice(deviceId);
    const record: PresenceRecord = {
      deviceId,
      state,
      lastHeartbeatAt: this.now().toISOString(),
    };
    if (activeSessionId !== undefined) {
      record.activeSessionId = activeSessionId;
    }
    this.presence.set(deviceId, record);
    return record;
  }

  getPresence(deviceId: string): PresenceRecord | undefined {
    return this.presence.get(deviceId);
  }

  enqueueRequest(input: {
    userId: string;
    targetDeviceId: string;
    sessionId?: string;
    kind: string;
    expiresAt: string;
    idempotencyKey: string;
    payload: Record<string, unknown>;
  }): RelayRequest {
    this.requireDevice(input.targetDeviceId);
    const existingId = this.requestByIdempotency.get(
      this.idempotencyScope(input.userId, input.targetDeviceId, input.idempotencyKey),
    );
    if (existingId) {
      const existing = this.requests.get(existingId);
      if (existing) return existing;
    }

    const request: RelayRequest = {
      requestId: randomUUID(),
      userId: input.userId,
      targetDeviceId: input.targetDeviceId,
      kind: input.kind,
      createdAt: this.now().toISOString(),
      expiresAt: input.expiresAt,
      idempotencyKey: input.idempotencyKey,
      payload: input.payload,
      status: "queued",
    };
    if (input.sessionId !== undefined) {
      request.sessionId = input.sessionId;
    }
    this.requests.set(request.requestId, request);
    this.requestByIdempotency.set(
      this.idempotencyScope(input.userId, input.targetDeviceId, input.idempotencyKey),
      request.requestId,
    );
    return request;
  }

  ackRequest(requestId: string, status: Exclude<RequestStatus, "queued">): RelayRequest {
    const request = this.requests.get(requestId);
    if (!request) throw new Error("request not found");
    request.status = Date.parse(request.expiresAt) <= this.now().getTime() ? "expired" : status;
    return request;
  }

  private registerDevice(
    userId: string,
    role: DeviceRole,
    name: string,
  ): DeviceRegistrationResult {
    const deviceId = randomUUID();
    const token = signDeviceToken(
      {
        userId,
        deviceId,
        role,
        issuedAt: this.now().toISOString(),
      },
      this.tokenSecret,
    );
    this.devices.set(deviceId, {
      id: deviceId,
      userId,
      role,
      name,
      tokenHash: hashToken(token, this.tokenSecret),
      createdAt: this.now().toISOString(),
    });
    return { deviceId, deviceToken: token };
  }

  private createPairingCode(userId: string, macDeviceId: string, ttlMs: number): string {
    const code = String(Math.floor(100000 + Math.random() * 900000));
    this.pairingCodes.set(code, {
      code,
      userId,
      macDeviceId,
      expiresAt: new Date(this.now().getTime() + ttlMs).toISOString(),
    });
    return code;
  }

  private requireDevice(deviceId: string): DeviceRecord {
    const device = this.devices.get(deviceId);
    if (!device) throw new Error("device not found");
    return device;
  }

  private idempotencyScope(userId: string, targetDeviceId: string, key: string): string {
    return `${userId}:${targetDeviceId}:${key}`;
  }
}
