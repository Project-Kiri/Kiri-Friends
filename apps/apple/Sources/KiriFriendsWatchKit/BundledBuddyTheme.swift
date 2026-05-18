// BundledBuddyTheme.swift
// Hand-curated registry of buddy theme packs shipped inside the
// `KiriFriendsWatchKit` resource bundle. Each entry maps every
// `BuddyPersonaState` to an asset name in the bundled Asset Catalog
// (`Resources/Themes.xcassets`). Asset names are namespaced by theme
// identifier (e.g. `clawd/clawd-happy`) because the catalog uses
// `provides-namespace = true` per theme group.
//
// Files are derivative of the upstream
// [clawd-on-desk](https://github.com/rullerzhou-afk/clawd-on-desk)
// theme packages and ship under AGPL-3.0 along with the rest of this
// target. See `docs/operations/license-boundaries.md`.

import Foundation
import KiriFriendsCore

public struct BundledBuddyTheme: Sendable, Hashable, Identifiable {
    public let manifest: BuddyAssetManifest
    /// Namespace prefix used inside `Themes.xcassets`. The Asset Catalog
    /// resolves each asset as `"<namespace>/<state-filename-stem>"`.
    public let namespace: String
    public let animationSpec: BuddyAnimationSpec?

    public init(
        manifest: BuddyAssetManifest,
        namespace: String,
        animationSpec: BuddyAnimationSpec? = nil
    ) {
        self.manifest = manifest
        self.namespace = namespace
        self.animationSpec = animationSpec
    }

    public var id: String { manifest.identifier }

    /// Returns the asset catalog name (including theme namespace) for
    /// the primary asset associated with `state`. Pass this directly to
    /// `Image(_:bundle:)` with `bundle: .module`. Nil indicates the
    /// bundled theme is missing an asset for that state — UI code
    /// should fall back to an SF Symbol when this happens.
    public func assetName(for state: BuddyPersonaState) -> String? {
        guard let filename = manifest.states[state, default: []].first else { return nil }
        let dotIndex = filename.lastIndex(of: ".") ?? filename.endIndex
        let stem = String(filename[..<dotIndex])
        return "\(namespace)/\(stem)"
    }

    /// The on-disk imageset directory for this state, used for tests
    /// and the `make verify-watch-assets` lint. Resolves nil when the
    /// catalog is missing (only happens in tests with custom bundles).
    public func imagesetURL(for state: BuddyPersonaState) -> URL? {
        guard let filename = manifest.states[state, default: []].first else { return nil }
        let dotIndex = filename.lastIndex(of: ".") ?? filename.endIndex
        let stem = String(filename[..<dotIndex])
        return Bundle.module.url(
            forResource: stem,
            withExtension: "imageset",
            subdirectory: "Themes.xcassets/\(namespace)"
        )
    }
}

public enum BundledBuddyThemeRegistry {
    public static let clawd = BundledBuddyTheme(
        manifest: BuddyAssetManifest(
            identifier: "com.kirifriends.clawd",
            displayName: "Clawd",
            version: "1.0.0",
            author: "rullerzhou-afk",
            thumbnail: "clawd-happy.svg",
            states: [
                .sleep: ["clawd-sleeping.svg"],
                .idle: ["clawd-idle-follow.svg"],
                .running: ["clawd-working-typing.svg"],
                .attention: ["clawd-happy.svg"],
                .celebrate: ["clawd-happy.svg"],
                .dizzy: ["clawd-error.svg"],
                .heart: ["clawd-idle-doze.svg"],
                .failed: ["clawd-error.svg"],
            ]
        ),
        namespace: "clawd",
        animationSpec: .clawd
    )

    public static let calico = BundledBuddyTheme(
        manifest: BuddyAssetManifest(
            identifier: "com.kirifriends.calico",
            displayName: "Calico",
            version: "1.0.0",
            author: "clawd-on-desk authors",
            thumbnail: "calico-happy.apng",
            states: [
                .sleep: ["calico-sleeping.apng"],
                .idle: ["calico-idle.apng"],
                .running: ["calico-thinking.apng"],
                .attention: ["calico-happy.apng"],
                .celebrate: ["calico-happy.apng"],
                .dizzy: ["calico-error.apng"],
                .heart: ["calico-idle.apng"],
                .failed: ["calico-error.apng"],
            ]
        ),
        namespace: "calico"
    )

    public static let cloudling = BundledBuddyTheme(
        manifest: BuddyAssetManifest(
            identifier: "com.kirifriends.cloudling",
            displayName: "Cloudling",
            version: "1.0.0",
            author: "clawd-on-desk authors",
            thumbnail: "cloudling-attention.svg",
            states: [
                .sleep: ["cloudling-mini-sleep.svg"],
                .idle: ["cloudling-idle.svg"],
                .running: ["cloudling-juggling.svg"],
                .attention: ["cloudling-attention.svg"],
                .celebrate: ["cloudling-attention.svg"],
                .dizzy: ["cloudling-error.svg"],
                .heart: ["cloudling-idle-reading.svg"],
                .failed: ["cloudling-error.svg"],
            ]
        ),
        namespace: "cloudling"
    )

    public static let all: [BundledBuddyTheme] = [clawd, calico, cloudling]

    public static let defaultTheme: BundledBuddyTheme = clawd

    /// Returns the theme matching the given identifier (typically
    /// `BuddySettings.activeManifestId`), falling back to the default
    /// when the identifier is unknown or nil. Useful for binding the
    /// active manifest from `BuddySettings` without dealing with
    /// optional chaining at every call site.
    public static func theme(identifier: String?) -> BundledBuddyTheme {
        guard let identifier else { return defaultTheme }
        return all.first { $0.manifest.identifier == identifier } ?? defaultTheme
    }
}
