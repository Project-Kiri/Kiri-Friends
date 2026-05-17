# Kiri Friends CLI Plugins

This TypeScript workspace contains host CLI integration helpers for Claude Code, Codex, and OpenCode.

Initial scope:

- Shared plugin event envelope.
- Timeout and redaction helpers.
- Local Mac bridge client.
- Codex `PermissionRequest` fail-open flow.
- Claude lifecycle event forwarding.
- OpenCode plugin source generation.
- Install/uninstall pure functions that preserve user-owned configuration.

## Commands

```bash
npm install
npm test
npm run typecheck
```
