// Development entry point for `npm run start` and `make dev-relay`.
// Keeps the bootstrap separate from the library exports so the
// `RelayStore` + HTTP layer can stay framework-free and importable.

import { listenHTTPServer } from "./http-server.js";
import { RelayStore } from "./relay-store.js";

const tokenSecret = process.env.KIRI_RELAY_TOKEN_SECRET ?? "dev-only-secret-change-me";
const port = Number.parseInt(process.env.KIRI_RELAY_PORT ?? "8585", 10);
const host = process.env.KIRI_RELAY_HOST ?? "127.0.0.1";

const store = new RelayStore({ tokenSecret });
const handle = await listenHTTPServer({ store, port, host });

const logHandlePort = handle.port;
process.stdout.write(
  `Kiri Relay listening on http://${host}:${logHandlePort}\n`,
);

process.on("SIGINT", () => {
  handle
    .close()
    .catch(() => undefined)
    .finally(() => process.exit(0));
});
process.on("SIGTERM", () => {
  handle
    .close()
    .catch(() => undefined)
    .finally(() => process.exit(0));
});
