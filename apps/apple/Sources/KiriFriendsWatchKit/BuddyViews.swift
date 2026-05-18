import KiriFriendsCore
import SwiftUI

public struct BuddyHomeView: View {
    private let snapshot: StateSnapshot
    private let theme: BundledBuddyTheme

    @Environment(\.isLuminanceReduced) private var isLuminanceReduced
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    public init(
        snapshot: StateSnapshot,
        theme: BundledBuddyTheme = BundledBuddyThemeRegistry.defaultTheme
    ) {
        self.snapshot = snapshot
        self.theme = theme
    }

    public var body: some View {
        let presentation = BuddyPresentationReducer.presentation(
            for: snapshot,
            isLuminanceReduced: isLuminanceReduced
        )

        // Keep the layout glanceable per watchos-design-guidelines W-GL-01:
        // buddy art and one summary line fit the first screen without
        // becoming a scroll container. Approval actions appear in the
        // foreground prompt owned by the Watch app.
        VStack(spacing: 6) {
            Spacer(minLength: 0)
            BuddyStageView(
                snapshot: snapshot,
                presentation: presentation,
                theme: theme,
                reduceMotion: reduceMotion,
                isLuminanceReduced: isLuminanceReduced,
                stageSize: 132
            )
            BuddySpeechBubble(line: presentation.speech, redactsText: isLuminanceReduced)
            ConnectionBadgeView(connectionState: snapshot.connectionState)
            Spacer(minLength: 0)
        }
        .offset(y: stageVisualLift)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(.horizontal, 8)
        .padding(.vertical, 10)
    }

    private var stageVisualLift: CGFloat {
        // The desktop buddy sprites include top-heavy transparent padding.
        // Lifting the compact Watch stack centers the visible pet, not the
        // source asset canvas plus caption.
        -26
    }
}

public struct BuddyStageView: View {
    let snapshot: StateSnapshot
    let presentation: BuddyPresentation
    let theme: BundledBuddyTheme
    let reduceMotion: Bool
    let isLuminanceReduced: Bool
    let stageSize: CGFloat

    public init(
        snapshot: StateSnapshot,
        presentation: BuddyPresentation,
        theme: BundledBuddyTheme = BundledBuddyThemeRegistry.defaultTheme,
        reduceMotion: Bool = false,
        isLuminanceReduced: Bool = false,
        stageSize: CGFloat = 104
    ) {
        self.snapshot = snapshot
        self.presentation = presentation
        self.theme = theme
        self.reduceMotion = reduceMotion
        self.isLuminanceReduced = isLuminanceReduced
        self.stageSize = stageSize
    }

    public var body: some View {
        // The buddy expression communicates the persona state visually, so
        // we deliberately omit the raw "Attention/Running/..." caption per
        // watchos-design-guidelines W-GL-04 and the project copy rule about
        // redundant text. VoiceOver still announces the state.
        BuddyAnimationPlayer(
            request: BuddyAnimationResolver.request(
                for: snapshot,
                presentation: presentation,
                theme: theme,
                isLuminanceReduced: isLuminanceReduced
            ),
            fallbackAssetName: BuddyStageAssetResolver.assetName(for: presentation.state, in: theme),
            fallbackSymbolName: BuddyStageAssetResolver.symbolFallback(for: presentation.state),
            reduceMotion: reduceMotion,
            stageSize: stageSize
        )
            .accessibilityElement()
            .accessibilityLabel("Kiri is \(presentation.state.rawValue)")
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
        let text = line.text.trimmingCharacters(in: .whitespacesAndNewlines)
        if !text.isEmpty {
            Text(redactsText ? "Kiri is nearby." : text)
                .font(.caption)
                .multilineTextAlignment(.center)
                .lineLimit(3)
                .padding(8)
                .frame(maxWidth: .infinity)
                .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 12))
                .privacySensitive(line.sensitivity != .none)
        }
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
