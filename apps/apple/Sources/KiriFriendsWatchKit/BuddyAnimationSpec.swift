import Foundation
import KiriFriendsCore

public enum BuddyDesktopVisualState: String, Codable, Hashable, Sendable, CaseIterable {
    case idle
    case yawning
    case dozing
    case collapsing
    case thinking
    case working
    case juggling
    case sweeping
    case error
    case attention
    case notification
    case carrying
    case sleeping
    case waking
}

public struct BuddyAnimationRect: Codable, Hashable, Sendable {
    public var x: Double
    public var y: Double
    public var width: Double
    public var height: Double

    public init(x: Double, y: Double, width: Double, height: Double) {
        self.x = x
        self.y = y
        self.width = width
        self.height = height
    }
}

public struct BuddyAnimationLayout: Codable, Hashable, Sendable {
    public var viewBox: BuddyAnimationRect
    public var contentBox: BuddyAnimationRect
    public var centerX: Double
    public var baselineY: Double
    public var visibleHeightRatio: Double
    public var baselineBottomRatio: Double

    public init(
        viewBox: BuddyAnimationRect,
        contentBox: BuddyAnimationRect,
        centerX: Double,
        baselineY: Double,
        visibleHeightRatio: Double,
        baselineBottomRatio: Double
    ) {
        self.viewBox = viewBox
        self.contentBox = contentBox
        self.centerX = centerX
        self.baselineY = baselineY
        self.visibleHeightRatio = visibleHeightRatio
        self.baselineBottomRatio = baselineBottomRatio
    }
}

public struct BuddyAnimationTier: Codable, Hashable, Sendable {
    public var minSessions: Int
    public var file: String

    public init(minSessions: Int, file: String) {
        self.minSessions = minSessions
        self.file = file
    }
}

public struct BuddyIdleAnimation: Codable, Hashable, Sendable {
    public var file: String
    public var durationMs: Int

    public init(file: String, durationMs: Int) {
        self.file = file
        self.durationMs = durationMs
    }
}

public struct BuddyAnimationTiming: Codable, Hashable, Sendable {
    public var minDisplayMs: [BuddyDesktopVisualState: Int]
    public var autoReturnMs: [BuddyDesktopVisualState: Int]

    public init(
        minDisplayMs: [BuddyDesktopVisualState: Int] = [:],
        autoReturnMs: [BuddyDesktopVisualState: Int] = [:]
    ) {
        self.minDisplayMs = minDisplayMs
        self.autoReturnMs = autoReturnMs
    }
}

public struct BuddyAnimationSpec: Codable, Hashable, Sendable {
    public var states: [BuddyDesktopVisualState: [String]]
    public var workingTiers: [BuddyAnimationTier]
    public var jugglingTiers: [BuddyAnimationTier]
    public var idleAnimations: [BuddyIdleAnimation]
    public var displayHintMap: [String: String]
    public var timings: BuddyAnimationTiming
    public var layout: BuddyAnimationLayout

    public init(
        states: [BuddyDesktopVisualState: [String]],
        workingTiers: [BuddyAnimationTier] = [],
        jugglingTiers: [BuddyAnimationTier] = [],
        idleAnimations: [BuddyIdleAnimation] = [],
        displayHintMap: [String: String] = [:],
        timings: BuddyAnimationTiming = BuddyAnimationTiming(),
        layout: BuddyAnimationLayout
    ) {
        self.states = states
        self.workingTiers = workingTiers
        self.jugglingTiers = jugglingTiers
        self.idleAnimations = idleAnimations
        self.displayHintMap = displayHintMap
        self.timings = timings
        self.layout = layout
    }

    public func primaryFile(for state: BuddyDesktopVisualState) -> String? {
        states[state, default: []].first
    }

    public func tieredWorkingFile(activeSessions: Int) -> String? {
        tieredFile(in: workingTiers, activeSessions: activeSessions) ?? primaryFile(for: .working)
    }

    public func tieredJugglingFile(activeSessions: Int) -> String? {
        tieredFile(in: jugglingTiers, activeSessions: activeSessions) ?? primaryFile(for: .juggling)
    }

    private func tieredFile(in tiers: [BuddyAnimationTier], activeSessions: Int) -> String? {
        tiers
            .sorted { $0.minSessions > $1.minSessions }
            .first { activeSessions >= $0.minSessions }?
            .file
    }

    public static let clawd = BuddyAnimationSpec(
        states: [
            .idle: ["clawd-idle-follow.svg"],
            .yawning: ["clawd-idle-yawn.svg"],
            .dozing: ["clawd-idle-doze.svg"],
            .collapsing: ["clawd-collapse-sleep.svg"],
            .thinking: ["clawd-working-thinking.svg"],
            .working: ["clawd-working-typing.svg"],
            .juggling: ["clawd-headphones-groove.svg"],
            .sweeping: ["clawd-working-sweeping.svg"],
            .error: ["clawd-error.svg"],
            .attention: ["clawd-happy.svg"],
            .notification: ["clawd-notification.svg"],
            .carrying: ["clawd-working-carrying.svg"],
            .sleeping: ["clawd-sleeping.svg"],
            .waking: ["clawd-wake.svg"],
        ],
        workingTiers: [
            BuddyAnimationTier(minSessions: 3, file: "clawd-working-building.svg"),
            BuddyAnimationTier(minSessions: 2, file: "clawd-headphones-groove.svg"),
            BuddyAnimationTier(minSessions: 1, file: "clawd-working-typing.svg"),
        ],
        jugglingTiers: [
            BuddyAnimationTier(minSessions: 2, file: "clawd-working-juggling.svg"),
            BuddyAnimationTier(minSessions: 1, file: "clawd-headphones-groove.svg"),
        ],
        idleAnimations: [
            BuddyIdleAnimation(file: "clawd-idle-look.svg", durationMs: 6_500),
            BuddyIdleAnimation(file: "clawd-working-debugger.svg", durationMs: 14_000),
            BuddyIdleAnimation(file: "clawd-idle-reading.svg", durationMs: 14_000),
        ],
        displayHintMap: [
            "clawd-working-building.svg": "clawd-working-building.svg",
            "clawd-working-typing.svg": "clawd-working-typing.svg",
            "clawd-headphones-groove.svg": "clawd-headphones-groove.svg",
            "clawd-working-juggling.svg": "clawd-working-juggling.svg",
            "clawd-working-conducting.svg": "clawd-working-juggling.svg",
            "clawd-idle-reading.svg": "clawd-idle-reading.svg",
            "clawd-working-debugger.svg": "clawd-working-debugger.svg",
            "clawd-working-thinking.svg": "clawd-working-thinking.svg",
        ],
        timings: BuddyAnimationTiming(
            minDisplayMs: [
                .attention: 4_000,
                .error: 5_000,
                .sweeping: 5_500,
                .notification: 5_000,
                .carrying: 3_000,
                .working: 1_000,
                .thinking: 1_000,
            ],
            autoReturnMs: [
                .attention: 4_000,
                .error: 5_000,
                .sweeping: 300_000,
                .notification: 5_000,
                .carrying: 3_000,
            ]
        ),
        layout: BuddyAnimationLayout(
            viewBox: BuddyAnimationRect(x: -15, y: -25, width: 45, height: 45),
            contentBox: BuddyAnimationRect(x: -4, y: -3, width: 23, height: 20),
            centerX: 7.5,
            baselineY: 17,
            visibleHeightRatio: 0.58,
            baselineBottomRatio: 0.05
        )
    )
}

public struct BuddyAnimationRequest: Hashable, Sendable, Identifiable {
    public var themeNamespace: String
    public var visualState: BuddyDesktopVisualState
    public var sourceFile: String
    public var layout: BuddyAnimationLayout

    public init(
        themeNamespace: String,
        visualState: BuddyDesktopVisualState,
        sourceFile: String,
        layout: BuddyAnimationLayout
    ) {
        self.themeNamespace = themeNamespace
        self.visualState = visualState
        self.sourceFile = sourceFile
        self.layout = layout
    }

    public var id: String {
        "\(themeNamespace)/\(visualState.rawValue)/\(sourceFile)"
    }

    public var frameDirectoryName: String {
        sourceFile.removingPathExtension
    }
}

private extension String {
    var removingPathExtension: String {
        guard let dotIndex = lastIndex(of: ".") else { return self }
        return String(self[..<dotIndex])
    }
}
