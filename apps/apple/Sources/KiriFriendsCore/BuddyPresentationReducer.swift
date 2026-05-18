import Foundation

public enum BuddyPresentationReducer {
    public static func presentation(
        for snapshot: StateSnapshot,
        stats: BuddyStats = BuddyStats(),
        isLuminanceReduced: Bool = false
    ) -> BuddyPresentation {
        let state = personaState(for: snapshot, isLuminanceReduced: isLuminanceReduced)
        let mood = mood(for: snapshot, stats: stats)
        let energy = energy(for: snapshot.healthSummary)
        let speech = speechLine(for: snapshot, state: state, isLuminanceReduced: isLuminanceReduced)
        let primaryAction = primaryAction(for: snapshot)

        return BuddyPresentation(
            state: state,
            mood: mood,
            energy: energy,
            speech: speech,
            primaryAction: primaryAction,
            isSensitive: speech.sensitivity == .private || speech.sensitivity == .secret
        )
    }

    public static func complicationSnapshot(for snapshot: StateSnapshot) -> ComplicationSnapshot {
        let status = statusText(for: snapshot)
        let detail = appendAdditionalSessionsIndicator(to: status.detail, snapshot: snapshot)
        return ComplicationSnapshot(
            updatedAt: snapshot.updatedAt,
            shortStatus: status.title,
            detail: detail,
            symbolName: status.symbolName,
            sensitivity: status.sensitivity
        )
    }

    /// Convenience badge metadata used by the watch HUD and the iPhone
    /// session row. Each tool gets an SF Symbol pulled from
    /// `CLITool.symbolName` plus its human-friendly name.
    public static func agentBadge(for tool: CLITool) -> (symbolName: String, label: String) {
        (tool.symbolName, tool.displayName)
    }

    private static func appendAdditionalSessionsIndicator(to detail: String?, snapshot: StateSnapshot) -> String? {
        let extra = snapshot.additionalSessionCount
        guard extra > 0 else { return detail }
        let suffix = "+\(extra)"
        guard let detail, !detail.isEmpty else { return suffix }
        return "\(detail) \(suffix)"
    }

    private static func personaState(
        for snapshot: StateSnapshot,
        isLuminanceReduced: Bool
    ) -> BuddyPersonaState {
        if isLuminanceReduced { return .sleep }

        switch snapshot.session?.state {
        case .waitingForApproval:
            return .attention
        case .running:
            return .running
        case .completed:
            return .celebrate
        case .failed:
            return .failed
        case .waitingForInput:
            return .heart
        case .idle, .unknown, .none:
            return snapshot.connectionState == .relayConnected ? .idle : .sleep
        }
    }

    private static func mood(for snapshot: StateSnapshot, stats: BuddyStats) -> BuddyMood {
        if snapshot.session?.state == .failed { return .concerned }
        if snapshot.session?.state == .completed { return .excited }
        if snapshot.healthSummary?.activityState == .stressed { return .concerned }
        if let median = stats.medianApprovalSeconds, median < 5 { return .excited }
        if snapshot.session?.state == .running { return .focused }
        return .calm
    }

    private static func energy(for summary: HealthSignalSummary?) -> BuddyEnergy {
        guard let summary else { return .steady }
        if summary.energyLevel <= 1 { return .low }
        if summary.energyLevel >= 4 { return .high }
        return .steady
    }

    private static func speechLine(
        for snapshot: StateSnapshot,
        state: BuddyPersonaState,
        isLuminanceReduced: Bool
    ) -> BuddySpeechLine {
        if isLuminanceReduced {
            return BuddySpeechLine(text: "Resting nearby.", sensitivity: .none)
        }

        if let approval = snapshot.approval {
            return BuddySpeechLine(text: approval.summary, sensitivity: approval.sensitivity)
        }

        if let session = snapshot.session {
            return BuddySpeechLine(text: session.summary, sensitivity: session.sensitivity)
        }

        switch state {
        case .sleep:
            return BuddySpeechLine(text: "Waiting for your iPhone.", sensitivity: .none)
        case .idle:
            return BuddySpeechLine(text: "Ready when you are.", sensitivity: .none)
        case .running:
            return BuddySpeechLine(text: "Kiri is working.", sensitivity: .none)
        case .attention:
            return BuddySpeechLine(text: "Action needed.", sensitivity: .none)
        case .celebrate:
            return BuddySpeechLine(text: "Task complete.", sensitivity: .none)
        case .dizzy, .failed:
            return BuddySpeechLine(text: "Something needs attention.", sensitivity: .none)
        case .heart:
            return BuddySpeechLine(text: "Waiting for your reply.", sensitivity: .none)
        }
    }

    private static func primaryAction(for snapshot: StateSnapshot) -> WatchActionKind? {
        // Only surface a button when a CLI hook actually needs a reply
        // from the user. Idle / running / completed / failed states are
        // informational; surfacing a generic "Refresh" or "Stop" button
        // there would violate the project rule against placeholder actions
        // and clutter the glanceable Status tab.
        switch snapshot.session?.state {
        case .waitingForApproval:
            return .approvalAllow
        case .waitingForInput:
            return .promptSendQuick
        case .running, .idle, .failed, .completed, .unknown, .none:
            return nil
        }
    }

    private static func statusText(for snapshot: StateSnapshot) -> (
        title: String,
        detail: String?,
        symbolName: String,
        sensitivity: PayloadSensitivity
    ) {
        switch snapshot.session?.state {
        case .waitingForApproval:
            return ("Approval", "Action needed", "hand.tap", .none)
        case .running:
            return ("Running", snapshot.activeTool.rawValue, "play.fill", .none)
        case .completed:
            return ("Done", snapshot.activeTool.rawValue, "checkmark", .none)
        case .failed:
            return ("Failed", "Open Kiri", "exclamationmark.triangle", .none)
        case .waitingForInput:
            return ("Waiting", "Reply needed", "text.bubble", .none)
        case .idle, .unknown, .none:
            let isOnline = snapshot.connectionState == .relayConnected
            return (isOnline ? "Ready" : "Offline", nil, isOnline ? "sparkles" : "wifi.slash", .none)
        }
    }
}
