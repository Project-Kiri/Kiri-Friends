import { createHmac, timingSafeEqual } from "node:crypto";

import type { DeviceRole } from "./types.js";

export type DeviceTokenClaims = {
  userId: string;
  deviceId: string;
  role: DeviceRole;
  issuedAt: string;
};

export function signDeviceToken(claims: DeviceTokenClaims, secret: string): string {
  const body = Buffer.from(JSON.stringify(claims), "utf8").toString("base64url");
  const signature = createHmac("sha256", secret).update(body).digest("base64url");
  return `${body}.${signature}`;
}

export function verifyDeviceToken(token: string, secret: string): DeviceTokenClaims | null {
  const [body, signature] = token.split(".");
  if (!body || !signature) return null;

  const expected = createHmac("sha256", secret).update(body).digest("base64url");
  if (!safeEqual(signature, expected)) return null;

  try {
    return JSON.parse(Buffer.from(body, "base64url").toString("utf8")) as DeviceTokenClaims;
  } catch {
    return null;
  }
}

export function hashToken(token: string, secret: string): string {
  return createHmac("sha256", secret).update(token).digest("hex");
}

function safeEqual(left: string, right: string): boolean {
  const leftBuffer = Buffer.from(left);
  const rightBuffer = Buffer.from(right);
  return leftBuffer.length === rightBuffer.length && timingSafeEqual(leftBuffer, rightBuffer);
}
