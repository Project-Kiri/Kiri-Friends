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
  RelayEvent,
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
  private readonly events = new Map<string, RelayEvent>();
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
    return this.registerHostBridge(userId, deviceName, "mac_bridge", pairingTtlMs);
  }

  registerCLIHostBridge(
    userId: string,
    deviceName: string,
    pairingTtlMs = 5 * 60 * 1000,
  ): MacRegistrationResult {
    return this.registerHostBridge(userId, deviceName, "cli_host_bridge", pairingTtlMs);
  }

  private registerHostBridge(
    userId: string,
    deviceName: string,
    role: DeviceRole,
    pairingTtlMs: number,
  ): MacRegistrationResult {
    const device = this.registerDevice(userId, role, deviceName);
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

  getPresenceForUser(userId: string, deviceId: string): PresenceRecord | undefined {
    const device = this.devices.get(deviceId);
    if (!device || device.userId !== userId || device.revokedAt) return undefined;
    return this.presence.get(deviceId);
  }

  listPresenceForUser(userId: string): PresenceRecord[] {
    const ownedDeviceIds = new Set(
      [...this.devices.values()]
        .filter((device) => device.userId === userId && !device.revokedAt)
        .map((device) => device.id),
    );
    return [...this.presence.values()]
      .filter((record) => ownedDeviceIds.has(record.deviceId))
      .sort((left, right) => Date.parse(right.lastHeartbeatAt) - Date.parse(left.lastHeartbeatAt));
  }

  ingestEvent(input: {
    userId: string;
    sourceDeviceId: string;
    version?: 1;
    tool?: string;
    event: string;
    sessionId?: string;
    cwd?: string;
    createdAt?: string;
    payload: Record<string, unknown>;
    sensitivity?: RelayEvent["sensitivity"];
  }): RelayEvent {
    const source = this.requireDevice(input.sourceDeviceId);
    if (source.userId !== input.userId) {
      throw new Error("event source is not owned by user");
    }
    if (source.role !== "mac_bridge" && source.role !== "cli_host_bridge") {
      throw new Error("only CLI hosts can ingest events");
    }

    const event: RelayEvent = {
      eventId: randomUUID(),
      userId: input.userId,
      sourceDeviceId: input.sourceDeviceId,
      event: input.event,
      createdAt: input.createdAt ?? this.now().toISOString(),
      payload: input.payload,
      sensitivity: input.sensitivity ?? "preview",
    };
    if (input.version !== undefined) event.version = input.version;
    if (input.tool !== undefined) event.tool = input.tool;
    if (input.cwd !== undefined) event.cwd = input.cwd;
    if (input.sessionId !== undefined) event.sessionId = input.sessionId;
    this.events.set(event.eventId, event);
    return event;
  }

  listEventsForUser(userId: string): RelayEvent[] {
    return [...this.events.values()]
      .filter((event) => event.userId === userId)
      .sort((left, right) => Date.parse(left.createdAt) - Date.parse(right.createdAt));
  }

  listPendingRequests(targetDeviceId: string): RelayRequest[] {
    const nowMs = this.now().getTime();
    return [...this.requests.values()]
      .filter((request) => request.targetDeviceId === targetDeviceId)
      .filter((request) => request.status === "queued")
      .filter((request) => Date.parse(request.expiresAt) > nowMs)
      .sort((left, right) => Date.parse(left.createdAt) - Date.parse(right.createdAt));
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
      updatedAt: this.now().toISOString(),
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

  getRequest(requestId: string): RelayRequest | undefined {
    return this.requests.get(requestId);
  }

  ackRequest(
    requestId: string,
    status: Exclude<RequestStatus, "queued">,
    details: { result?: Record<string, unknown>; error?: string } = {},
  ): RelayRequest {
    const request = this.requests.get(requestId);
    if (!request) throw new Error("request not found");
    const now = this.now().toISOString();
    request.status = Date.parse(request.expiresAt) <= this.now().getTime() ? "expired" : status;
    request.updatedAt = now;
    if (status === "accepted") {
      request.acknowledgedAt = now;
    }
    if (status === "completed" || status === "failed" || status === "expired" || status === "superseded") {
      request.completedAt = now;
    }
    if (details.result !== undefined) request.result = details.result;
    if (details.error !== undefined) request.error = details.error;
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
