// BuddyThemeAssets.swift
// Locates the bundled themes shipped with KiriFriendsBuddyMac and
// resolves SVG / APNG asset URLs through the shared `ThemeLoader`
// implementation in MacBuddyKit. Phase 4 promotes this from the
// hard-coded Phase 2 mapping to a real theme-driven lookup.

import Foundation
import KiriFriendsMacBuddyKit

public enum BuddyThemeAssets {
    public static let bundledThemeIdentifier = "clawd"

    /// Directory inside the resource bundle that contains all bundled
    /// themes. Empty when the bundle has no Themes subdirectory (which
    /// would indicate a packaging bug).
    public static var bundledThemesDirectory: URL? {
        Bundle.module.url(forResource: "Themes", withExtension: nil)
    }

    /// Loads the theme manifest by identifier, returning nil when the
    /// theme is not bundled with the executable.
    public static func bundledTheme(identifier: String) async -> LoadedTheme? {
        guard let bundled = bundledThemesDirectory else { return nil }
        let loader = ThemeLoader(searchRoots: [bundled])
        return try? await loader.theme(withIdentifier: identifier)
    }

    public static func listBundledThemes() async -> [LoadedTheme] {
        guard let bundled = bundledThemesDirectory else { return [] }
        let loader = ThemeLoader(searchRoots: [bundled])
        return await loader.availableThemes()
    }

    /// Phase 2 compatibility helper: resolves a state to the bundled
    /// Clawd theme's primary asset. Phase 4 generalises this by going
    /// through the active `LoadedTheme`.
    public static func svgURL(for state: MacBuddyState) async -> URL? {
        guard let theme = await bundledTheme(identifier: bundledThemeIdentifier) else { return nil }
        guard let file = theme.descriptor.primaryFile(for: state) else { return nil }
        return theme.assetURL(filename: file)
    }
}
