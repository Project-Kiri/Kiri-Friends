export const KIRI_MARKER = "kiri-friends";
export const KIRI_STATUS_MESSAGE = "Kiri Friends hook";

export type InstallPlan = {
  path: string;
  nextText: string;
  backupRequired: boolean;
};

export function addJsonHookEntry(
  currentText: string | null,
  path: string,
  hookName: string,
  command: string,
  options: {
    matcher?: string;
    timeoutSec?: number;
    async?: boolean;
    statusMessage?: string;
  } = {},
): InstallPlan {
  const parsed = currentText ? (JSON.parse(currentText) as Record<string, unknown>) : {};
  const hooks = ensureRecord(parsed, "hooks");
  const existing = Array.isArray(hooks[hookName]) ? (hooks[hookName] as unknown[]) : [];
  const handler: Record<string, unknown> = {
    type: "command",
    command,
    statusMessage: options.statusMessage ?? KIRI_STATUS_MESSAGE,
  };
  if (options.timeoutSec !== undefined) handler.timeout = options.timeoutSec;
  if (options.async !== undefined) handler.async = options.async;

  const kiriEntry: Record<string, unknown> = {
    hooks: [
      handler,
    ],
  };
  if (options.matcher !== undefined) kiriEntry.matcher = options.matcher;
  hooks[hookName] = [
    ...existing.filter((entry) => !isKiriEntry(entry)),
    kiriEntry,
  ];
  return {
    path,
    nextText: `${JSON.stringify(parsed, null, 2)}\n`,
    backupRequired: currentText !== null,
  };
}

export function removeKiriEntries(currentText: string): string {
  const parsed = JSON.parse(currentText) as Record<string, unknown>;
  const hooks = parsed.hooks;
  if (!hooks || typeof hooks !== "object" || Array.isArray(hooks)) {
    return `${JSON.stringify(parsed, null, 2)}\n`;
  }

  for (const [hookName, entries] of Object.entries(hooks)) {
    if (!Array.isArray(entries)) continue;
    const kept = entries.filter((entry) => !isKiriEntry(entry));
    if (kept.length === 0) {
      delete (hooks as Record<string, unknown>)[hookName];
    } else {
      (hooks as Record<string, unknown>)[hookName] = kept;
    }
  }
  return `${JSON.stringify(parsed, null, 2)}\n`;
}

function isKiriEntry(entry: unknown): boolean {
  const text = JSON.stringify(entry);
  return text.includes(KIRI_MARKER) || text.includes(KIRI_STATUS_MESSAGE);
}

function ensureRecord(parent: Record<string, unknown>, key: string): Record<string, unknown> {
  const value = parent[key];
  if (value && typeof value === "object" && !Array.isArray(value)) {
    return value as Record<string, unknown>;
  }
  const next: Record<string, unknown> = {};
  parent[key] = next;
  return next;
}
