import Foundation
import Testing
@testable import KiriFriendsCore
@testable import KiriFriendsWatchKit

@Suite("BundledBuddyTheme")
struct BundledBuddyThemeTests {
    @Test("Registry lists the three documented themes")
    func registryListsAllThemes() {
        let ids = BundledBuddyThemeRegistry.all.map(\.manifest.identifier).sorted()
        #expect(ids == [
            "com.kirifriends.calico",
            "com.kirifriends.clawd",
            "com.kirifriends.cloudling",
        ])
    }

    @Test("theme(identifier:) falls back to clawd")
    func unknownIdentifierFallsBackToClawd() {
        let resolved = BundledBuddyThemeRegistry.theme(identifier: "totally.unknown")
        #expect(resolved.manifest.identifier == "com.kirifriends.clawd")

        let nilResolved = BundledBuddyThemeRegistry.theme(identifier: nil)
        #expect(nilResolved.manifest.identifier == "com.kirifriends.clawd")
    }

    @Test("theme(identifier:) returns the requested theme")
    func knownIdentifierResolves() {
        let calico = BundledBuddyThemeRegistry.theme(identifier: "com.kirifriends.calico")
        #expect(calico.manifest.displayName == "Calico")
        let cloudling = BundledBuddyThemeRegistry.theme(identifier: "com.kirifriends.cloudling")
        #expect(cloudling.manifest.displayName == "Cloudling")
    }

    @Test("Every theme covers all 8 persona states")
    func manifestsCoverEveryPersonaState() {
        for theme in BundledBuddyThemeRegistry.all {
            #expect(
                theme.manifest.missingRequiredStates.isEmpty,
                "\(theme.manifest.identifier) is missing \(theme.manifest.missingRequiredStates)"
            )
        }
    }

    @Test("All 24 theme x persona combinations produce an asset name")
    func everyAssetCombinationProducesAName() {
        for theme in BundledBuddyThemeRegistry.all {
            for state in BuddyPersonaState.allCases {
                let name = theme.assetName(for: state)
                #expect(name != nil, "\(theme.manifest.identifier).\(state.rawValue) has no asset name")
                #expect(name?.hasPrefix("\(theme.namespace)/") == true)
            }
        }
    }

    @Test("All 24 imagesets exist on disk inside the asset catalog")
    func everyImagesetExistsOnDisk() {
        for theme in BundledBuddyThemeRegistry.all {
            for state in BuddyPersonaState.allCases {
                let url = theme.imagesetURL(for: state)
                #expect(url != nil, "\(theme.manifest.identifier).\(state.rawValue) has no imageset URL")
                if let url {
                    var isDir: ObjCBool = false
                    let exists = FileManager.default.fileExists(atPath: url.path, isDirectory: &isDir)
                    #expect(exists && isDir.boolValue, "missing imageset directory at \(url.path)")
                }
            }
        }
    }

    @Test("BuddyStageAssetResolver returns namespaced names for every state")
    func resolverReturnsNamespacedNames() {
        for theme in BundledBuddyThemeRegistry.all {
            for state in BuddyPersonaState.allCases {
                let name = BuddyStageAssetResolver.assetName(for: state, in: theme)
                #expect(name?.hasPrefix("\(theme.namespace)/") == true)
            }
        }
    }

    @Test("BuddyStageAssetResolver SF Symbol fallback covers every state")
    func resolverSymbolFallbackExhaustive() {
        for state in BuddyPersonaState.allCases {
            let symbol = BuddyStageAssetResolver.symbolFallback(for: state)
            #expect(!symbol.isEmpty)
        }
    }

    @Test("Default BuddySettings identifier resolves to clawd")
    func defaultSettingsIdentifierResolvesToClawd() {
        let settings = BuddySettings(
            activeManifestId: BundledBuddyThemeRegistry.defaultTheme.manifest.identifier,
            buddyName: "Clawd",
            showsPreviewText: false,
            sharesAgentHealthContext: false
        )
        let resolved = BundledBuddyThemeRegistry.theme(identifier: settings.activeManifestId)
        #expect(resolved.manifest.identifier == "com.kirifriends.clawd")
        #expect(resolved.manifest.displayName == "Clawd")
    }

    @Test("Clawd animation spec mirrors desktop visual states")
    func clawdAnimationSpecMirrorsDesktopStates() {
        let spec = BundledBuddyThemeRegistry.clawd.animationSpec
        #expect(spec?.primaryFile(for: .idle) == "clawd-idle-follow.svg")
        #expect(spec?.primaryFile(for: .working) == "clawd-working-typing.svg")
        #expect(spec?.primaryFile(for: .notification) == "clawd-notification.svg")
        #expect(spec?.primaryFile(for: .error) == "clawd-error.svg")
        #expect(spec?.primaryFile(for: .sleeping) == "clawd-sleeping.svg")
    }

    @Test("Clawd working tiers match desktop thresholds")
    func clawdWorkingTiersMatchDesktopThresholds() {
        let tiers = BundledBuddyThemeRegistry.clawd.animationSpec?.workingTiers
        #expect(tiers?.map(\.minSessions) == [3, 2, 1])
        #expect(tiers?.map(\.file) == [
            "clawd-working-building.svg",
            "clawd-headphones-groove.svg",
            "clawd-working-typing.svg",
        ])
    }

    @Test("Frame manifests exist for key Clawd states")
    func frameManifestsExistForKeyClawdStates() {
        let theme = BundledBuddyThemeRegistry.clawd
        let spec = theme.animationSpec
        let files = [
            spec?.primaryFile(for: .notification),
            spec?.primaryFile(for: .working),
            spec?.primaryFile(for: .error),
            spec?.tieredWorkingFile(activeSessions: 3),
        ].compactMap { $0 }

        for file in files {
            let request = BuddyAnimationRequest(
                themeNamespace: theme.namespace,
                visualState: .working,
                sourceFile: file,
                layout: spec?.layout ?? .clawdFallback
            )
            let manifest = BuddyAnimationFrameCatalog.manifest(for: request)
            #expect(manifest != nil, "missing frame manifest for \(file)")
            #expect(manifest?.frames.isEmpty == false, "\(file) has no generated frames")
        }
    }
}

private extension BuddyAnimationLayout {
    static let clawdFallback = BuddyAnimationLayout(
        viewBox: BuddyAnimationRect(x: -15, y: -25, width: 45, height: 45),
        contentBox: BuddyAnimationRect(x: -4, y: -3, width: 23, height: 20),
        centerX: 7.5,
        baselineY: 17,
        visibleHeightRatio: 0.58,
        baselineBottomRatio: 0.05
    )
}
