// AgentDescriptor.swift
// Ports the per-agent module shape from
// .workspace/reference/clawd-on-desk/agents/<agent>.js into Swift. The
// shape is a static configuration record: identifier, process names,
// hook event source, event → buddy state mapping, and capability flags.

import Foundation

public enum AgentEventSource: String, Codable, Hashable, Sendable {
    case hook
    case extensionRuntime = "extension"
    case pluginEvent = "plugin-event"
    case hookWithLogPoll = "hook+log-poll"
    case logPoll = "log-poll"
}

public struct AgentCapabilities: Codable, Hashable, Sendable {
    public var httpHook: Bool
    public var permissionApproval: Bool
    public var notificationHook: Bool
    public var interactiveBubble: Bool
    public var sessionEnd: Bool
    public var subagent: Bool

    public init(
        httpHook: Bool = false,
        permissionApproval: Bool = false,
        notificationHook: Bool = false,
        interactiveBubble: Bool = false,
        sessionEnd: Bool = false,
        subagent: Bool = false
    ) {
        self.httpHook = httpHook
        self.permissionApproval = permissionApproval
        self.notificationHook = notificationHook
        self.interactiveBubble = interactiveBubble
        self.sessionEnd = sessionEnd
        self.subagent = subagent
    }
}

public struct AgentProcessNames: Codable, Hashable, Sendable {
    public var macOS: [String]
    public var windows: [String]
    public var linux: [String]

    public init(macOS: [String], windows: [String] = [], linux: [String] = []) {
        self.macOS = macOS
        self.windows = windows
        self.linux = linux
    }

    /// Returns the process names that should be matched against running
    /// processes on the host platform. Mirrors clawd `getAllProcessNames`
    /// which collapses linux → mac when linux is empty.
    public var current: [String] {
        #if os(macOS)
        return macOS
        #elseif os(Linux)
        return linux.isEmpty ? macOS : linux
        #elseif os(Windows)
        return windows
        #else
        return macOS
        #endif
    }
}

public struct AgentDescriptor: Codable, Hashable, Sendable {
    public var identifier: AgentIdentifier
    public var displayName: String
    public var eventSource: AgentEventSource
    public var processNames: AgentProcessNames
    public var eventMap: [String: MacBuddyState]
    public var capabilities: AgentCapabilities
    public var pidField: String

    public init(
        identifier: AgentIdentifier,
        displayName: String,
        eventSource: AgentEventSource,
        processNames: AgentProcessNames,
        eventMap: [String: MacBuddyState],
        capabilities: AgentCapabilities,
        pidField: String
    ) {
        self.identifier = identifier
        self.displayName = displayName
        self.eventSource = eventSource
        self.processNames = processNames
        self.eventMap = eventMap
        self.capabilities = capabilities
        self.pidField = pidField
    }

    /// Resolves an incoming hook event name to the buddy state it should
    /// drive. Returns nil when the event is not present in this agent's
    /// map; callers should treat unknown events as no-op state mutations.
    public func state(forEvent event: String) -> MacBuddyState? {
        eventMap[event]
    }
}
