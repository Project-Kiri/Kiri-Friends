// DoctorReport.swift
// Bridge health snapshot that mirrors the upstream Clawd doctor command
// (see `.workspace/reference/clawd-on-desk/src/doctor.js`). Phase 9 only
// surfaces locally available facts; CLI install inspection (e.g. is
// `claude` on PATH) ships in a follow-up once the install scripts move
// out of the upstream JavaScript port.

import Foundation

public struct DoctorReport: Codable, Sendable, Hashable {
    public enum Severity: String, Codable, Sendable, Hashable {
        case ok
        case info
        case warning
        case critical
    }

    public struct Finding: Codable, Sendable, Hashable, Identifiable {
        public var id: String
        public var severity: Severity
        public var title: String
        public var detail: String

        public init(id: String, severity: Severity, title: String, detail: String) {
            self.id = id
            self.severity = severity
            self.title = title
            self.detail = detail
        }
    }

    public var generatedAt: Date
    public var bridgePort: UInt16?
    public var sessionCount: Int
    public var displayState: MacBuddyState
    public var permissionLocked: Bool
    public var doNotDisturb: Bool
    public var bundledThemeCount: Int
    public var findings: [Finding]

    public init(
        generatedAt: Date,
        bridgePort: UInt16?,
        sessionCount: Int,
        displayState: MacBuddyState,
        permissionLocked: Bool,
        doNotDisturb: Bool,
        bundledThemeCount: Int,
        findings: [Finding]
    ) {
        self.generatedAt = generatedAt
        self.bridgePort = bridgePort
        self.sessionCount = sessionCount
        self.displayState = displayState
        self.permissionLocked = permissionLocked
        self.doNotDisturb = doNotDisturb
        self.bundledThemeCount = bundledThemeCount
        self.findings = findings
    }
}

public actor DoctorService {
    private let store: MacBuddyStateStore
    private let dnd: DoNotDisturbState

    public init(store: MacBuddyStateStore, dnd: DoNotDisturbState) {
        self.store = store
        self.dnd = dnd
    }

    public func generate(bridgePort: UInt16?, bundledThemeCount: Int) async -> DoctorReport {
        let snapshot = await store.currentSnapshot()
        let dndEnabled = await dnd.isEnabled

        var findings: [DoctorReport.Finding] = []
        if bridgePort == nil {
            findings.append(DoctorReport.Finding(
                id: "bridge-port",
                severity: .critical,
                title: "Bridge not listening",
                detail: "The HTTP bridge does not have a bound port. Plugin scripts will not be able to reach Kiri Buddy."
            ))
        } else {
            findings.append(DoctorReport.Finding(
                id: "bridge-port",
                severity: .ok,
                title: "Bridge listening",
                detail: "Bridge HTTP listener bound to 127.0.0.1:\(bridgePort!)."
            ))
        }
        if bundledThemeCount == 0 {
            findings.append(DoctorReport.Finding(
                id: "themes",
                severity: .warning,
                title: "No bundled themes",
                detail: "The buddy executable was packaged without the Themes resource directory."
            ))
        }
        if dndEnabled {
            findings.append(DoctorReport.Finding(
                id: "dnd",
                severity: .info,
                title: "Do Not Disturb is on",
                detail: "Permission bubbles and state events are silenced; agents fall back to native prompts."
            ))
        }
        if snapshot.permissionLocked {
            findings.append(DoctorReport.Finding(
                id: "permission-lock",
                severity: .info,
                title: "Permission request pending",
                detail: "A permission bubble is currently displayed and the buddy is locked on notification."
            ))
        }

        return DoctorReport(
            generatedAt: Date(),
            bridgePort: bridgePort,
            sessionCount: snapshot.sessions.count,
            displayState: snapshot.displayState,
            permissionLocked: snapshot.permissionLocked,
            doNotDisturb: dndEnabled,
            bundledThemeCount: bundledThemeCount,
            findings: findings
        )
    }
}
