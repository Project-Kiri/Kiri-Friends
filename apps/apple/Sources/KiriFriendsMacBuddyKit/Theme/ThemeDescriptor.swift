// ThemeDescriptor.swift
// Swift value types modelling the Clawd-on-Desk `theme.json` format.
// Schema mirrors
// `.workspace/reference/clawd-on-desk/src/theme-schema.js` so themes
// authored against the upstream documentation parse without change. The
// Phase 4 surface only consumes the fields the Mac Buddy needs today
// (states, eye tracking, layout, timings, hit boxes, reactions); unused
// keys are kept as raw JSON for forward compatibility.

import Foundation

public struct ThemeRect: Codable, Sendable, Hashable {
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

public struct ThemeLayout: Codable, Sendable, Hashable {
    public var contentBox: ThemeRect?
    public var marginBox: ThemeRect?
    public var centerX: Double?
    public var baselineY: Double?
    public var visibleHeightRatio: Double?
    public var baselineBottomRatio: Double?
}

public struct ThemeEyeTrackingIDs: Codable, Sendable, Hashable {
    public var eyes: String?
    public var body: String?
    public var shadow: String?
    public var dozeEyes: String?

    public init(eyes: String? = nil, body: String? = nil, shadow: String? = nil, dozeEyes: String? = nil) {
        self.eyes = eyes
        self.body = body
        self.shadow = shadow
        self.dozeEyes = dozeEyes
    }
}

public struct ThemeEyeTracking: Codable, Sendable, Hashable {
    public var enabled: Bool
    public var states: [String]?
    public var eyeRatioX: Double?
    public var eyeRatioY: Double?
    public var maxOffset: Double?
    public var bodyScale: Double?
    public var shadowStretch: Double?
    public var shadowShift: Double?
    public var ids: ThemeEyeTrackingIDs?
    public var shadowOrigin: String?

    public static let disabled = ThemeEyeTracking(enabled: false)

    public init(
        enabled: Bool,
        states: [String]? = nil,
        eyeRatioX: Double? = nil,
        eyeRatioY: Double? = nil,
        maxOffset: Double? = nil,
        bodyScale: Double? = nil,
        shadowStretch: Double? = nil,
        shadowShift: Double? = nil,
        ids: ThemeEyeTrackingIDs? = nil,
        shadowOrigin: String? = nil
    ) {
        self.enabled = enabled
        self.states = states
        self.eyeRatioX = eyeRatioX
        self.eyeRatioY = eyeRatioY
        self.maxOffset = maxOffset
        self.bodyScale = bodyScale
        self.shadowStretch = shadowStretch
        self.shadowShift = shadowShift
        self.ids = ids
        self.shadowOrigin = shadowOrigin
    }

    public var asConfiguration: BuddyEyeTrackingConfiguration? {
        guard enabled else { return nil }
        return BuddyEyeTrackingConfiguration(
            maxOffset: maxOffset ?? BuddyEyeTrackingConfiguration.clawd.maxOffset,
            bodyScale: bodyScale ?? BuddyEyeTrackingConfiguration.clawd.bodyScale,
            shadowStretch: shadowStretch ?? BuddyEyeTrackingConfiguration.clawd.shadowStretch,
            shadowShift: shadowShift ?? BuddyEyeTrackingConfiguration.clawd.shadowShift
        )
    }
}

public struct BuddyEyeTrackingConfiguration: Sendable, Hashable {
    public var maxOffset: Double
    public var bodyScale: Double
    public var shadowStretch: Double
    public var shadowShift: Double

    public init(maxOffset: Double, bodyScale: Double, shadowStretch: Double, shadowShift: Double) {
        self.maxOffset = maxOffset
        self.bodyScale = bodyScale
        self.shadowStretch = shadowStretch
        self.shadowShift = shadowShift
    }

    public static let clawd = BuddyEyeTrackingConfiguration(
        maxOffset: 3,
        bodyScale: 0.33,
        shadowStretch: 0.15,
        shadowShift: 0.3
    )
}

public struct ThemeTimings: Codable, Sendable, Hashable {
    public var minDisplay: [String: Int]
    public var autoReturn: [String: Int]
    public var yawnDuration: Int?
    public var wakeDuration: Int?
    public var deepSleepTimeout: Int?
    public var mouseIdleTimeout: Int?
    public var mouseSleepTimeout: Int?

    public init(
        minDisplay: [String: Int] = [:],
        autoReturn: [String: Int] = [:],
        yawnDuration: Int? = nil,
        wakeDuration: Int? = nil,
        deepSleepTimeout: Int? = nil,
        mouseIdleTimeout: Int? = nil,
        mouseSleepTimeout: Int? = nil
    ) {
        self.minDisplay = minDisplay
        self.autoReturn = autoReturn
        self.yawnDuration = yawnDuration
        self.wakeDuration = wakeDuration
        self.deepSleepTimeout = deepSleepTimeout
        self.mouseIdleTimeout = mouseIdleTimeout
        self.mouseSleepTimeout = mouseSleepTimeout
    }

    public func storeTimings() -> MacBuddyStateStore.Timings {
        MacBuddyStateStore.Timings(
            attention: .milliseconds(autoReturn["attention"] ?? 4_000),
            error: .milliseconds(autoReturn["error"] ?? 5_000),
            sweeping: .milliseconds(autoReturn["sweeping"] ?? 5_500),
            notification: .milliseconds(autoReturn["notification"] ?? 5_000),
            carrying: .milliseconds(autoReturn["carrying"] ?? 3_000)
        )
    }
}

public struct ThemeHitBox: Codable, Sendable, Hashable {
    public var x: Double
    public var y: Double
    public var w: Double
    public var h: Double
}

public struct ThemeHitBoxes: Codable, Sendable, Hashable {
    public var `default`: ThemeHitBox?
    public var sleeping: ThemeHitBox?
    public var wide: ThemeHitBox?

    public init(`default`: ThemeHitBox? = nil, sleeping: ThemeHitBox? = nil, wide: ThemeHitBox? = nil) {
        self.default = `default`
        self.sleeping = sleeping
        self.wide = wide
    }
}

public struct ThemeReactionEntry: Codable, Sendable, Hashable {
    public var file: String?
    public var files: [String]?
    public var duration: Int?
}

public struct ThemeReactions: Codable, Sendable, Hashable {
    public var drag: ThemeReactionEntry?
    public var clickLeft: ThemeReactionEntry?
    public var clickRight: ThemeReactionEntry?
    public var annoyed: ThemeReactionEntry?
    public var double: ThemeReactionEntry?
}

public struct ThemeTierEntry: Codable, Sendable, Hashable {
    public var minSessions: Int
    public var file: String
}

public struct ThemeIdleAnimation: Codable, Sendable, Hashable {
    public var file: String
    public var duration: Int
}

public struct ThemeMiniMode: Codable, Sendable, Hashable {
    public var supported: Bool?
    public var offsetRatio: Double?
    public var states: [String: [String]]?
}

public struct ThemeDescriptor: Codable, Sendable, Hashable {
    public var schemaVersion: Int
    public var name: String
    public var author: String?
    public var version: String
    public var description: String?
    public var repo: String?
    public var viewBox: ThemeRect?
    public var layout: ThemeLayout?
    public var eyeTracking: ThemeEyeTracking?
    public var states: [String: [String]]
    public var workingTiers: [ThemeTierEntry]?
    public var jugglingTiers: [ThemeTierEntry]?
    public var idleAnimations: [ThemeIdleAnimation]?
    public var displayHintMap: [String: String]?
    public var updateVisuals: [String: String]?
    public var timings: ThemeTimings?
    public var hitBoxes: ThemeHitBoxes?
    public var fileHitBoxes: [String: ThemeHitBox]?
    public var wideHitboxFiles: [String]?
    public var sleepingHitboxFiles: [String]?
    public var reactions: ThemeReactions?
    public var miniMode: ThemeMiniMode?
    public var sounds: [String: String]?

    public init(
        schemaVersion: Int,
        name: String,
        version: String,
        states: [String: [String]],
        author: String? = nil,
        description: String? = nil,
        repo: String? = nil,
        viewBox: ThemeRect? = nil,
        layout: ThemeLayout? = nil,
        eyeTracking: ThemeEyeTracking? = nil,
        workingTiers: [ThemeTierEntry]? = nil,
        jugglingTiers: [ThemeTierEntry]? = nil,
        idleAnimations: [ThemeIdleAnimation]? = nil,
        displayHintMap: [String: String]? = nil,
        updateVisuals: [String: String]? = nil,
        timings: ThemeTimings? = nil,
        hitBoxes: ThemeHitBoxes? = nil,
        fileHitBoxes: [String: ThemeHitBox]? = nil,
        wideHitboxFiles: [String]? = nil,
        sleepingHitboxFiles: [String]? = nil,
        reactions: ThemeReactions? = nil,
        miniMode: ThemeMiniMode? = nil,
        sounds: [String: String]? = nil
    ) {
        self.schemaVersion = schemaVersion
        self.name = name
        self.version = version
        self.states = states
        self.author = author
        self.description = description
        self.repo = repo
        self.viewBox = viewBox
        self.layout = layout
        self.eyeTracking = eyeTracking
        self.workingTiers = workingTiers
        self.jugglingTiers = jugglingTiers
        self.idleAnimations = idleAnimations
        self.displayHintMap = displayHintMap
        self.updateVisuals = updateVisuals
        self.timings = timings
        self.hitBoxes = hitBoxes
        self.fileHitBoxes = fileHitBoxes
        self.wideHitboxFiles = wideHitboxFiles
        self.sleepingHitboxFiles = sleepingHitboxFiles
        self.reactions = reactions
        self.miniMode = miniMode
        self.sounds = sounds
    }

    /// Returns the SVG / GIF / APNG file expected for the buddy state.
    /// Mirrors upstream `state-visual-resolver.js#resolveVisualBinding`
    /// for the simple "use the first entry" case; tier resolution still
    /// lives in a follow-up file.
    public func primaryFile(for state: MacBuddyState) -> String? {
        // Map MacBuddyState to the canonical theme state key. The Clawd
        // theme keeps `working` and `sweeping` etc. exactly matched to
        // our enum's raw values, so a direct rawValue lookup works.
        let key = state.rawValue
        if let entries = states[key], let file = entries.first {
            return file
        }
        // Fall back through closely related states so themes with fewer
        // assets degrade gracefully.
        switch state {
        case .yawning, .dozing, .collapsing, .waking:
            return states["sleeping"]?.first ?? states["idle"]?.first
        case .juggling:
            return states["working"]?.first ?? states["idle"]?.first
        case .carrying, .sweeping, .attention, .notification:
            return states["working"]?.first ?? states["idle"]?.first
        case .error:
            return states["error"]?.first ?? states["idle"]?.first
        default:
            return states["idle"]?.first
        }
    }
}
