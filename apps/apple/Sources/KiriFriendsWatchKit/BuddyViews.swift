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

        ScrollView {
            VStack(spacing: 10) {
                BuddyStageView(
                    presentation: presentation,
                    theme: theme,
                    reduceMotion: reduceMotion
                )
                BuddySpeechBubble(line: presentation.speech, redactsText: isLuminanceReduced)
                ConnectionBadgeView(connectionState: snapshot.connectionState)

                if let action = presentation.primaryAction {
                    Button(primaryActionTitle(for: action)) {
                        playHaptic(for: action)
                        sendAction(makeAction(action))
                    }
                    .buttonStyle(.borderedProminent)
                    .primaryHandGesture(isEnabled: action == .approvalAllow && snapshot.approval?.sensitivity != .private)
                    .accessibilityHint(primaryActionHint(for: action))
                }
            }
            .padding()
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

    private func primaryActionTitle(for action: WatchActionKind) -> String {
        switch action {
        case .approvalAllow:
            return "Approve"
        case .approvalDeny:
            return "Deny"
        case .taskStop:
            return "Stop"
        case .promptSendQuick:
            return "Reply"
        case .statusRefresh:
            return "Refresh"
        }
    }

    private func primaryActionHint(for action: WatchActionKind) -> String {
        switch action {
        case .approvalAllow:
            return "Approves the current CLI action."
        case .approvalDeny:
            return "Denies the current CLI action."
        case .taskStop:
            return "Stops the current CLI task."
        case .promptSendQuick:
            return "Sends a quick reply to the active session."
        case .statusRefresh:
            return "Requests the latest CLI status."
        }
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

    @State private var isBreathing = false

    public init(
        presentation: BuddyPresentation,
        theme: BundledBuddyTheme = BundledBuddyThemeRegistry.defaultTheme,
        reduceMotion: Bool = false
    ) {
        self.presentation = presentation
        self.theme = theme
        self.reduceMotion = reduceMotion
    }

    public var body: some View {
        VStack(spacing: 6) {
            stageImage
                .frame(width: 96, height: 96)
                .scaleEffect(reduceMotion ? 1 : (isBreathing ? scale : 1.0))
                .animation(
                    reduceMotion
                        ? nil
                        : .easeInOut(duration: 1.6).repeatForever(autoreverses: true),
                    value: isBreathing
                )
                .onAppear { isBreathing = true }
                .accessibilityHidden(true)

            Text(presentation.state.rawValue.capitalized)
                .font(.headline)
                .lineLimit(1)
        }
        .accessibilityElement(children: .combine)
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
        } else {
            Image(systemName: BuddyStageAssetResolver.symbolFallback(for: presentation.state))
                .font(.system(size: 54))
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
        Label(title, systemImage: symbol)
            .font(.caption2)
            .foregroundStyle(color)
            .lineLimit(1)
    }

    private var title: String {
        switch connectionState {
        case .relayConnected:
            return "Relay connected"
        case .relayUnavailable:
            return "Relay unavailable"
        case .macOffline:
            return "CLI host offline"
        case .iphoneUnreachable:
            return "iPhone unreachable"
        case .unknown:
            return "Unknown"
        }
    }

    private var symbol: String {
        connectionState == .relayConnected ? "checkmark.circle.fill" : "exclamationmark.circle"
    }

    private var color: Color {
        connectionState == .relayConnected ? .green : .orange
    }
}

private extension View {
    @ViewBuilder
    func primaryHandGesture(isEnabled: Bool) -> some View {
        #if os(watchOS)
        if #available(watchOS 11.0, *) {
            self.handGestureShortcut(.primaryAction, isEnabled: isEnabled)
        } else {
            self
        }
        #else
        self
        #endif
    }
}
