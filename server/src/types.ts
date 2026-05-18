export type DeviceRole = "iphone_companion" | "cli_host_bridge" | "mac_bridge";

export type PresenceState = "online" | "idle" | "busy" | "waiting" | "offline";

export type RequestStatus =
  | "queued"
  | "accepted"
  | "completed"
  | "failed"
  | "expired"
  | "superseded";

export type RelayErrorCode =
  | "not_authenticated"
  | "not_authorized"
  | "device_not_found"
  | "pairing_required"
  | "target_offline"
  | "request_expired"
  | "rate_limited"
  | "payload_too_large"
  | "schema_version_unsupported"
  | "internal_error";

export type RelayError = {
  code: RelayErrorCode;
  message: string;
  retryable: boolean;
};

export type DeviceRecord = {
  id: string;
  userId: string;
  role: DeviceRole;
  name: string;
  tokenHash: string;
  createdAt: string;
  revokedAt?: string;
};

export type PairingRecord = {
  id: string;
  userId: string;
  iphoneDeviceId: string;
  macDeviceId: string;
  createdAt: string;
  revokedAt?: string;
};

export type PairingCodeRecord = {
  code: string;
  userId: string;
  macDeviceId: string;
  expiresAt: string;
  usedAt?: string;
};

export type PresenceRecord = {
  deviceId: string;
  state: PresenceState;
  activeSessionId?: string;
  lastHeartbeatAt: string;
};

export type RelayRequest = {
  requestId: string;
  userId: string;
  targetDeviceId: string;
  sessionId?: string;
  kind: string;
  createdAt: string;
  updatedAt: string;
  acknowledgedAt?: string;
  completedAt?: string;
  expiresAt: string;
  idempotencyKey: string;
  payload: Record<string, unknown>;
  result?: Record<string, unknown>;
  error?: string;
  status: RequestStatus;
};

export type RelayEvent = {
  eventId: string;
  version?: 1;
  userId: string;
  sourceDeviceId: string;
  tool?: string;
  event: string;
  sessionId?: string;
  cwd?: string;
  createdAt: string;
  payload: Record<string, unknown>;
  sensitivity: "none" | "preview" | "private" | "secret";
};

export type DeviceRegistrationResult = {
  deviceId: string;
  deviceToken: string;
};

export type MacRegistrationResult = DeviceRegistrationResult & {
  pairingCode: string;
  pairingExpiresAt: string;
};
