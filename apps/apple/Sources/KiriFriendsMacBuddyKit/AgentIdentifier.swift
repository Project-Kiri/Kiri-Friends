// AgentIdentifier.swift
// Stable identifier set for every supported CLI agent. The Phase 1 agent
// registry will hang descriptive metadata (display name, process names,
// install paths) off of these identifiers; Phase 0 only needs the enum
// so other modules can reference it.

import Foundation

public enum AgentIdentifier: String, Codable, Hashable, Sendable, CaseIterable {
    case claudeCode = "claude-code"
    case codex
    case copilotCli = "copilot-cli"
    case geminiCli = "gemini-cli"
    case cursorAgent = "cursor-agent"
    case codebuddy
    case kiroCli = "kiro-cli"
    case kimiCli = "kimi-cli"
    case opencode
    case pi
    case openclaw
    case hermes
}
