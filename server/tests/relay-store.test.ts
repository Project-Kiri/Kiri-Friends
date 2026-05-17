import assert from "node:assert/strict";
import test from "node:test";

import { RelayStore } from "../src/relay-store.js";

test("registers scoped iPhone and Mac devices", () => {
  const store = new RelayStore({ tokenSecret: "test-secret" });
  const iphone = store.registerIPhone("user-1", "iPhone");
  const mac = store.registerMac("user-1", "MacBook");
  const cliHost = store.registerCLIHostBridge("user-1", "CLI Host");

  assert.equal(store.authenticate(iphone.deviceToken)?.role, "iphone_companion");
  assert.equal(store.authenticate(mac.deviceToken)?.role, "mac_bridge");
  assert.equal(store.authenticate(cliHost.deviceToken)?.role, "cli_host_bridge");
  assert.equal(mac.pairingCode.length, 6);
});

test("approves a pairing code once", () => {
  const store = new RelayStore({ tokenSecret: "test-secret" });
  const iphone = store.registerIPhone("user-1", "iPhone");
  const mac = store.registerMac("user-1", "MacBook");
  const pairing = store.approvePairing("user-1", iphone.deviceId, mac.pairingCode);

  assert.equal(pairing.iphoneDeviceId, iphone.deviceId);
  assert.equal(pairing.macDeviceId, mac.deviceId);
  assert.throws(() => store.approvePairing("user-1", iphone.deviceId, mac.pairingCode));
});

test("tracks heartbeat presence", () => {
  const store = new RelayStore({ tokenSecret: "test-secret" });
  const mac = store.registerMac("user-1", "MacBook");
  store.heartbeat(mac.deviceId, "busy", "session-uuid");

  assert.equal(store.getPresence(mac.deviceId)?.state, "busy");
  assert.equal(store.getPresence(mac.deviceId)?.activeSessionId, "session-uuid");
});

test("deduplicates requests by idempotency key", () => {
  const store = new RelayStore({ tokenSecret: "test-secret" });
  const mac = store.registerMac("user-1", "MacBook");
  const expiresAt = new Date(Date.now() + 10_000).toISOString();
  const first = store.enqueueRequest({
    userId: "user-1",
    targetDeviceId: mac.deviceId,
    kind: "approval.decide",
    expiresAt,
    idempotencyKey: "same-key",
    payload: { decision: "allow" },
  });
  const second = store.enqueueRequest({
    userId: "user-1",
    targetDeviceId: mac.deviceId,
    kind: "approval.decide",
    expiresAt,
    idempotencyKey: "same-key",
    payload: { decision: "allow" },
  });

  assert.equal(second.requestId, first.requestId);
});

test("acks requests and respects expiration", () => {
  let current = new Date("2026-05-17T12:00:00Z");
  const store = new RelayStore({ tokenSecret: "test-secret", now: () => current });
  const mac = store.registerMac("user-1", "MacBook");
  const request = store.enqueueRequest({
    userId: "user-1",
    targetDeviceId: mac.deviceId,
    kind: "status.refresh",
    expiresAt: "2026-05-17T12:00:01Z",
    idempotencyKey: "refresh",
    payload: {},
  });

  assert.equal(store.ackRequest(request.requestId, "accepted").status, "accepted");
  current = new Date("2026-05-17T12:00:02Z");
  assert.equal(store.ackRequest(request.requestId, "completed").status, "expired");
});

test("ingests CLI host events and lists them for iPhone delivery", () => {
  const store = new RelayStore({ tokenSecret: "test-secret" });
  const host = store.registerCLIHostBridge("user-1", "CLI Host");

  const event = store.ingestEvent({
    userId: "user-1",
    sourceDeviceId: host.deviceId,
    event: "approval.requested",
    sessionId: "session-uuid",
    payload: { title: "Approve CLI action?" },
    sensitivity: "preview",
  });

  assert.equal(event.event, "approval.requested");
  assert.equal(store.listEventsForUser("user-1").length, 1);
  assert.equal(store.listEventsForUser("user-1")[0]?.sessionId, "session-uuid");
});

test("lists only unexpired pending downlink requests", () => {
  let current = new Date("2026-05-17T12:00:00Z");
  const store = new RelayStore({ tokenSecret: "test-secret", now: () => current });
  const host = store.registerCLIHostBridge("user-1", "CLI Host");
  store.enqueueRequest({
    userId: "user-1",
    targetDeviceId: host.deviceId,
    kind: "approval.decide",
    expiresAt: "2026-05-17T12:00:10Z",
    idempotencyKey: "allow-approval",
    payload: { decision: "allow" },
  });
  store.enqueueRequest({
    userId: "user-1",
    targetDeviceId: host.deviceId,
    kind: "task.stop",
    expiresAt: "2026-05-17T11:59:59Z",
    idempotencyKey: "expired-stop",
    payload: {},
  });

  assert.equal(store.listPendingRequests(host.deviceId).length, 1);
  current = new Date("2026-05-17T12:00:11Z");
  assert.equal(store.listPendingRequests(host.deviceId).length, 0);
});
