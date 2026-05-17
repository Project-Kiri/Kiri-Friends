const SECRET_KEY_PATTERN = /(token|secret|password|api[_-]?key|authorization)/i;

export function redactPayload(input: Record<string, unknown>): Record<string, unknown> {
  const output: Record<string, unknown> = {};
  for (const [key, value] of Object.entries(input)) {
    if (SECRET_KEY_PATTERN.test(key)) {
      output[key] = "[redacted]";
    } else if (typeof value === "string" && looksSensitive(value)) {
      output[key] = "[redacted]";
    } else {
      output[key] = value;
    }
  }
  return output;
}

export function summarizeCommand(input: unknown): string {
  if (typeof input !== "object" || input === null) return "CLI action";
  const record = input as Record<string, unknown>;
  const description = record.description;
  if (typeof description === "string" && description.trim()) return description.trim();
  const command = record.command;
  if (typeof command === "string" && command.trim()) return command.trim().slice(0, 80);
  return "CLI action";
}

function looksSensitive(value: string): boolean {
  return /Bearer\s+\S+|sk-[A-Za-z0-9_-]+|ghp_[A-Za-z0-9_]+/.test(value);
}
