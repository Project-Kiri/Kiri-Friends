// AgentRegistry.swift
// Swift port of .workspace/reference/clawd-on-desk/agents/registry.js plus
// the per-agent configuration files. Adding a new agent means appending
// a `AgentDescriptor` here and registering its hook script under
// plugins/src/.

import Foundation

public enum AgentRegistry {
    public static let all: [AgentDescriptor] = [
        claudeCode,
        codex,
        copilotCli,
        geminiCli,
        cursorAgent,
        codebuddy,
        kiroCli,
        kimiCli,
        opencode,
        pi,
        openclaw,
        hermes,
    ]

    public static func descriptor(for identifier: AgentIdentifier) -> AgentDescriptor? {
        all.first { $0.identifier == identifier }
    }

    public static let claudeCode = AgentDescriptor(
        identifier: .claudeCode,
        displayName: "Claude Code",
        eventSource: .hook,
        processNames: AgentProcessNames(macOS: ["claude"], windows: ["claude.exe"], linux: ["claude"]),
        eventMap: [
            "SessionStart": .idle,
            "SessionEnd": .sleeping,
            "UserPromptSubmit": .thinking,
            "PreToolUse": .working,
            "PostToolUse": .working,
            "PostToolUseFailure": .error,
            "Stop": .attention,
            "StopFailure": .error,
            "SubagentStart": .juggling,
            "SubagentStop": .working,
            "PreCompact": .sweeping,
            "PostCompact": .attention,
            "Notification": .notification,
            "Elicitation": .notification,
            "WorktreeCreate": .carrying,
        ],
        capabilities: AgentCapabilities(
            httpHook: true,
            permissionApproval: true,
            notificationHook: true,
            sessionEnd: true,
            subagent: true
        ),
        pidField: "claude_pid"
    )

    public static let codex = AgentDescriptor(
        identifier: .codex,
        displayName: "Codex CLI",
        eventSource: .hookWithLogPoll,
        processNames: AgentProcessNames(macOS: ["codex"], windows: ["codex.exe"], linux: ["codex"]),
        eventMap: [
            "SessionStart": .idle,
            "UserPromptSubmit": .thinking,
            "PreToolUse": .working,
            "PermissionRequest": .notification,
            "PostToolUse": .working,
            // Stop is special: the upstream monitor resolves "codex-turn-end"
            // into attention if a tool ran, idle otherwise. The Phase 1 port
            // models it as attention by default; the resolver-aware path
            // arrives with the JSONL fallback in Phase 6+.
            "Stop": .attention,
        ],
        capabilities: AgentCapabilities(
            permissionApproval: true,
            interactiveBubble: true
        ),
        pidField: "codex_pid"
    )

    public static let copilotCli = AgentDescriptor(
        identifier: .copilotCli,
        displayName: "Copilot CLI",
        eventSource: .hook,
        processNames: AgentProcessNames(macOS: ["copilot"], windows: ["copilot.exe"], linux: ["copilot"]),
        eventMap: [
            "sessionStart": .idle,
            "sessionEnd": .sleeping,
            "userPromptSubmitted": .thinking,
            "preToolUse": .working,
            "postToolUse": .working,
            "errorOccurred": .error,
            "agentStop": .attention,
            "subagentStart": .juggling,
            "subagentStop": .working,
            "preCompact": .sweeping,
        ],
        capabilities: AgentCapabilities(
            sessionEnd: true,
            subagent: true
        ),
        pidField: "copilot_pid"
    )

    public static let geminiCli = AgentDescriptor(
        identifier: .geminiCli,
        displayName: "Gemini CLI",
        eventSource: .hook,
        processNames: AgentProcessNames(macOS: ["gemini"], windows: ["gemini.exe"], linux: ["gemini"]),
        eventMap: [
            "SessionStart": .idle,
            "SessionEnd": .sleeping,
            "BeforeAgent": .thinking,
            "BeforeTool": .working,
            "AfterTool": .working,
            "AfterAgent": .idle,
            "Notification": .notification,
            "PreCompress": .idle,
        ],
        capabilities: AgentCapabilities(
            notificationHook: true,
            sessionEnd: true
        ),
        pidField: "gemini_pid"
    )

    public static let cursorAgent = AgentDescriptor(
        identifier: .cursorAgent,
        displayName: "Cursor Agent",
        eventSource: .hook,
        processNames: AgentProcessNames(
            macOS: ["Cursor"],
            windows: ["Cursor.exe"],
            linux: ["cursor", "Cursor"]
        ),
        eventMap: [
            "sessionStart": .idle,
            "sessionEnd": .sleeping,
            "beforeSubmitPrompt": .thinking,
            "preToolUse": .working,
            "postToolUse": .working,
            "postToolUseFailure": .working,
            "stop": .attention,
            "subagentStart": .juggling,
            "subagentStop": .working,
            "preCompact": .sweeping,
            "afterAgentThought": .thinking,
        ],
        capabilities: AgentCapabilities(
            sessionEnd: true,
            subagent: true
        ),
        pidField: "cursor_pid"
    )

    public static let codebuddy = AgentDescriptor(
        identifier: .codebuddy,
        displayName: "CodeBuddy",
        eventSource: .hook,
        processNames: AgentProcessNames(
            macOS: ["CodeBuddy"],
            windows: ["CodeBuddy.exe", "codebuddy.exe"],
            linux: ["codebuddy", "CodeBuddy"]
        ),
        eventMap: [
            "SessionStart": .idle,
            "SessionEnd": .sleeping,
            "UserPromptSubmit": .thinking,
            "PreToolUse": .working,
            "PostToolUse": .working,
            "Stop": .attention,
            "PermissionRequest": .notification,
            "Notification": .notification,
            "PreCompact": .sweeping,
        ],
        capabilities: AgentCapabilities(
            httpHook: true,
            permissionApproval: true,
            notificationHook: true,
            sessionEnd: true
        ),
        pidField: "codebuddy_pid"
    )

    public static let kiroCli = AgentDescriptor(
        identifier: .kiroCli,
        displayName: "Kiro CLI",
        eventSource: .hook,
        processNames: AgentProcessNames(macOS: ["kiro-cli"], windows: ["kiro-cli.exe"], linux: ["kiro-cli"]),
        eventMap: [
            "agentSpawn": .idle,
            "userPromptSubmit": .thinking,
            "preToolUse": .working,
            "postToolUse": .working,
            "stop": .attention,
        ],
        capabilities: AgentCapabilities(),
        pidField: "kiro_pid"
    )

    public static let kimiCli = AgentDescriptor(
        identifier: .kimiCli,
        displayName: "Kimi CLI",
        eventSource: .hook,
        processNames: AgentProcessNames(
            macOS: ["kimi", "Kimi Code"],
            windows: ["kimi.exe"],
            linux: ["kimi"]
        ),
        eventMap: [
            "SessionStart": .idle,
            "SessionEnd": .sleeping,
            "UserPromptSubmit": .thinking,
            "PreToolUse": .working,
            "PostToolUse": .working,
            "PostToolUseFailure": .error,
            "Stop": .attention,
            "StopFailure": .error,
            "SubagentStart": .juggling,
            "SubagentStop": .working,
            "PreCompact": .sweeping,
            "PostCompact": .attention,
            "Notification": .notification,
        ],
        capabilities: AgentCapabilities(
            httpHook: true,
            permissionApproval: true,
            notificationHook: true,
            sessionEnd: true,
            subagent: true
        ),
        pidField: "kimi_pid"
    )

    public static let opencode = AgentDescriptor(
        identifier: .opencode,
        displayName: "OpenCode",
        eventSource: .pluginEvent,
        processNames: AgentProcessNames(macOS: ["opencode"], windows: ["opencode.exe"], linux: ["opencode"]),
        eventMap: [
            "SessionStart": .idle,
            "SessionEnd": .sleeping,
            "UserPromptSubmit": .thinking,
            "PreToolUse": .working,
            "PostToolUse": .working,
            "PostToolUseFailure": .error,
            "Stop": .attention,
            "StopFailure": .error,
            "PreCompact": .sweeping,
            "PostCompact": .attention,
        ],
        capabilities: AgentCapabilities(
            permissionApproval: true,
            sessionEnd: true
        ),
        pidField: "opencode_pid"
    )

    public static let pi = AgentDescriptor(
        identifier: .pi,
        displayName: "Pi",
        eventSource: .extensionRuntime,
        processNames: AgentProcessNames(macOS: ["pi"], windows: ["pi.exe"], linux: ["pi"]),
        eventMap: [
            "SessionStart": .idle,
            "UserPromptSubmit": .thinking,
            "PreToolUse": .working,
            "PostToolUse": .working,
            "PostToolUseFailure": .error,
            "Stop": .attention,
            "PreCompact": .sweeping,
            "PostCompact": .attention,
            "SessionEnd": .sleeping,
        ],
        capabilities: AgentCapabilities(
            permissionApproval: true,
            interactiveBubble: true,
            sessionEnd: true
        ),
        pidField: "pi_pid"
    )

    public static let openclaw = AgentDescriptor(
        identifier: .openclaw,
        displayName: "OpenClaw",
        eventSource: .pluginEvent,
        // OpenClaw is invoked via `node openclaw.mjs`; matching `node` would
        // create false positives, so the Phase 1 port mirrors upstream and
        // leaves process detection empty.
        processNames: AgentProcessNames(macOS: [], windows: [], linux: []),
        eventMap: [
            "SessionStart": .idle,
            "UserPromptSubmit": .thinking,
            "PreToolUse": .working,
            "PostToolUse": .working,
            "PostToolUseFailure": .error,
            "Stop": .attention,
            "StopFailure": .error,
            "PreCompact": .sweeping,
            "PostCompact": .attention,
            "SessionEnd": .sleeping,
        ],
        capabilities: AgentCapabilities(
            sessionEnd: true
        ),
        pidField: "openclaw_pid"
    )

    public static let hermes = AgentDescriptor(
        identifier: .hermes,
        displayName: "Hermes Agent",
        eventSource: .pluginEvent,
        processNames: AgentProcessNames(macOS: ["hermes"], windows: ["hermes.exe"], linux: ["hermes"]),
        eventMap: [
            "SessionStart": .idle,
            "UserPromptSubmit": .thinking,
            "PreToolUse": .working,
            "PostToolUse": .working,
            "PostToolUseFailure": .error,
            "Stop": .attention,
            "StopFailure": .error,
            "SessionEnd": .sleeping,
        ],
        capabilities: AgentCapabilities(
            sessionEnd: true
        ),
        pidField: "hermes_pid"
    )
}
