import KiriFriendsCore
import SwiftUI

public struct BuddyHomeView: View {
    private let snapshot: StateSnapshot
    private let theme: BundledBuddyTheme
    private let sendAction: (WatchAction) -> Void

    @Environment(\.isLuminanceReduced) private var isLuminanceReduced
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    public init(
        snapshot: StateSnapshot,
        theme: BundledBuddyTheme = BundledBuddyThemeRegistry.defaultTheme,
        sendAction: @escaping (WatchAction) -> Void
    ) {
        self.snapshot = snapshot
        self.theme = theme
        self.sendAction = sendAction
    }

    public var body: some View {
        let presentation = BuddyPresentationReducer.presentation(
            for: snapshot,
            isLuminanceReduced: isLuminanceReduced
        )
        let pendingOptions = PendingWatchActionOption.options(for: snapshot)

        // Keep the layout glanceable per watchos-design-guidelines W-GL-01:
        // buddy art, one summary line, and the primary action must fit the
        // first screen. ScrollView remains so accessibility text sizes can
        // still grow without clipping the action.
        ScrollView {
            VStack(spacing: 4) {
                BuddyStageView(
                    presentation: presentation,
                    theme: theme,
                    reduceMotion: reduceMotion,
                    stageSize: pendingOptions.isEmpty ? 132 : 112
                )
                BuddySpeechBubble(line: presentation.speech, redactsText: isLuminanceReduced)
                ConnectionBadgeView(connectionState: snapshot.connectionState)

                PendingActionStrip(options: pendingOptions) { action in
                    playHaptic(for: action)
                    sendAction(makeAction(action))
                }
                .accessibilityHidden(presentation.primaryAction == nil)
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 6)
            .offset(y: pendingOptions.isEmpty ? 0 : -26)
        }
    }

    private func makeAction(_ action: WatchActionKind) -> WatchAction {
        WatchAction(
            action: action,
            sessionId: snapshot.session?.id ?? snapshot.approval?.sessionId,
            approvalId: snapshot.approval?.id,
            createdAt: .now
        )
    }

    private func playHaptic(for action: WatchActionKind) {
        switch action {
        case .approvalAllow:
            KiriHaptics.approvalAccepted()
        case .approvalDeny:
            KiriHaptics.approvalDenied()
        case .taskStop, .promptSendQuick, .statusRefresh:
            KiriHaptics.selectionChanged()
        }
    }
}

public struct BuddyStageView: View {
    let presentation: BuddyPresentation
    let theme: BundledBuddyTheme
    let reduceMotion: Bool
    let stageSize: CGFloat

    @State private var isBreathing = false

    public init(
        presentation: BuddyPresentation,
        theme: BundledBuddyTheme = BundledBuddyThemeRegistry.defaultTheme,
        reduceMotion: Bool = false,
        stageSize: CGFloat = 104
    ) {
        self.presentation = presentation
        self.theme = theme
        self.reduceMotion = reduceMotion
        self.stageSize = stageSize
    }

    public var body: some View {
        // The buddy expression communicates the persona state visually, so
        // we deliberately omit the raw "Attention/Running/..." caption per
        // watchos-design-guidelines W-GL-04 and the project copy rule about
        // redundant text. VoiceOver still announces the state.
        stageImage
            .frame(width: stageSize, height: stageSize)
            .scaleEffect(reduceMotion ? 1 : (isBreathing ? scale : 1.0))
            .animation(
                reduceMotion
                    ? nil
                    : .easeInOut(duration: 1.6).repeatForever(autoreverses: true),
                value: isBreathing
            )
            .onAppear { isBreathing = true }
            .accessibilityElement()
            .accessibilityLabel("Kiri is \(presentation.state.rawValue)")
    }

    @ViewBuilder
    private var stageImage: some View {
        if let assetName = BuddyStageAssetResolver.assetName(
            for: presentation.state,
            in: theme
        ) {
            Image(assetName, bundle: .module)
                .resizable()
                .interpolation(.none)
                .aspectRatio(contentMode: .fit)
                // The imported desktop sprites carry substantial transparent
                // padding; zoom them in so the character is the primary Watch
                // visual instead of a small icon inside the asset canvas.
                .scaleEffect(assetZoom)
        } else {
            Image(systemName: BuddyStageAssetResolver.symbolFallback(for: presentation.state))
                .font(.system(size: stageSize * 0.68))
        }
    }

    private var scale: CGFloat {
        switch presentation.state {
        case .running:
            return 1.08
        case .attention, .celebrate, .failed:
            return 1.04
        default:
            return 1.02
        }
    }

    private var assetZoom: CGFloat {
        switch theme.namespace {
        case "clawd":
            return 1.42
        case "cloudling":
            return 1.15
        default:
            return 1.25
        }
    }
}

/// Pure resolver layer extracted from `BuddyStageView` so the
/// theme-to-asset mapping is unit-testable without firing up SwiftUI.
public enum BuddyStageAssetResolver: Sendable {
    /// Returns the Asset Catalog name (namespaced by theme) for a given
    /// persona state. Nil indicates the theme has no asset registered;
    /// callers should fall back to `symbolFallback(for:)`.
    public static func assetName(
        for state: BuddyPersonaState,
        in theme: BundledBuddyTheme
    ) -> String? {
        theme.assetName(for: state)
    }

    /// Pre-AGPL SF Symbol fallback names. Used when the active theme
    /// is missing an asset for the requested state or the watch app
    /// is configured to disable buddy art.
    public static func symbolFallback(for state: BuddyPersonaState) -> String {
        switch state {
        case .sleep: return "moon.stars.fill"
        case .idle: return "sparkles"
        case .running: return "hammer.fill"
        case .attention: return "eye.fill"
        case .celebrate: return "party.popper.fill"
        case .dizzy: return "swirl.circle.righthalf.filled"
        case .heart: return "heart.fill"
        case .failed: return "exclamationmark.triangle.fill"
        }
    }
}

public struct BuddySpeechBubble: View {
    let line: BuddySpeechLine
    let redactsText: Bool

    public init(line: BuddySpeechLine, redactsText: Bool = false) {
        self.line = line
        self.redactsText = redactsText
    }

    public var body: some View {
        Text(redactsText ? "Kiri is nearby." : line.text)
            .font(.caption)
            .multilineTextAlignment(.center)
            .lineLimit(3)
            .padding(8)
            .frame(maxWidth: .infinity)
            .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 12))
            .privacySensitive(line.sensitivity != .none)
    }
}

public struct ConnectionBadgeView: View {
    let connectionState: ConnectionState

    public init(connectionState: ConnectionState) {
        self.connectionState = connectionState
    }

    public var body: some View {
        // Only surface the badge when something is wrong. A connected state
        // is the expected baseline; showing a row that says "Relay connected"
        // duplicates the buddy's idle expression and steals first-screen
        // real estate from the primary action.
        if let copy = problem {
            Label(copy.title, systemImage: copy.symbol)
                .font(.caption2)
                .foregroundStyle(.orange)
                .lineLimit(1)
        }
    }

    private struct ProblemCopy {
        var title: String
        var symbol: String
    }

    private var problem: ProblemCopy? {
        switch connectionState {
        case .relayConnected:
            return nil
        case .relayUnavailable:
            return ProblemCopy(title: "Relay unavailable", symbol: "exclamationmark.circle")
        case .macOffline:
            return ProblemCopy(title: "CLI host offline", symbol: "exclamationmark.circle")
        case .iphoneUnreachable:
            return ProblemCopy(title: "iPhone unreachable", symbol: "exclamationmark.circle")
        case .unknown:
            return ProblemCopy(title: "Connecting", symbol: "wifi.exclamationmark")
        }
    }
}
