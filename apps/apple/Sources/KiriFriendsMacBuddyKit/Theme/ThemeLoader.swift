// ThemeLoader.swift
// Discovers and loads `theme.json` files from a list of search paths
// (typically: bundled themes directory + user-installed themes directory
// under `~/.kirifriends/themes/`). Ports
// `.workspace/reference/clawd-on-desk/src/theme-loader.js` semantics
// without the SVG sanitizer (which is layered as a separate transform on
// the resolved SVG path inside the renderer; sanitisation happens in
// Phase 4 follow-up once we wire user themes end-to-end).

import Foundation

public struct LoadedTheme: Sendable, Hashable {
    public var identifier: String
    public var descriptor: ThemeDescriptor
    public var rootDirectory: URL
    public var assetsDirectory: URL

    public func assetURL(filename: String) -> URL {
        assetsDirectory.appending(path: filename, directoryHint: .notDirectory)
    }
}

public enum ThemeLoaderError: Error, Sendable, Hashable {
    case manifestNotFound(themeID: String)
    case manifestUnreadable(themeID: String, message: String)
    case manifestInvalidJSON(themeID: String, message: String)
}

public actor ThemeLoader {
    /// Candidate directory names that hold a theme's animated assets,
    /// resolved in order. Mirrors the upstream convention where Clawd
    /// keeps SVGs under `assets/svg/`, while imported Codex pet themes
    /// place sprites directly under `assets/`.
    public static let defaultAssetSubdirectories: [String] = ["svg", "assets", "."]

    private let fileManager: FileManager
    private let searchRoots: [URL]
    private let assetSubdirectories: [String]

    public init(
        searchRoots: [URL],
        assetSubdirectories: [String] = ThemeLoader.defaultAssetSubdirectories,
        fileManager: FileManager = .default
    ) {
        self.searchRoots = searchRoots
        self.assetSubdirectories = assetSubdirectories
        self.fileManager = fileManager
    }

    /// Returns every theme reachable from the configured search roots.
    /// Themes from earlier search roots take precedence over later ones
    /// with the same identifier (bundled vs user-installed override).
    public func availableThemes() -> [LoadedTheme] {
        var seenIDs: Set<String> = []
        var ordered: [LoadedTheme] = []
        for root in searchRoots {
            let directories = themeDirectories(in: root)
            for themeDir in directories {
                let identifier = themeDir.lastPathComponent
                guard !seenIDs.contains(identifier) else { continue }
                guard let descriptor = try? loadDescriptor(at: themeDir.appending(path: "theme.json")) else {
                    continue
                }
                let assetsDir = resolveAssetsDirectory(in: themeDir)
                seenIDs.insert(identifier)
                ordered.append(LoadedTheme(
                    identifier: identifier,
                    descriptor: descriptor,
                    rootDirectory: themeDir,
                    assetsDirectory: assetsDir
                ))
            }
        }
        return ordered.sorted { $0.descriptor.name < $1.descriptor.name }
    }

    public func theme(withIdentifier id: String) throws -> LoadedTheme {
        for root in searchRoots {
            let themeDir = root.appending(path: id, directoryHint: .isDirectory)
            let manifest = themeDir.appending(path: "theme.json")
            guard fileManager.fileExists(atPath: manifest.path) else { continue }
            let descriptor = try loadDescriptor(at: manifest)
            let assetsDir = resolveAssetsDirectory(in: themeDir)
            return LoadedTheme(
                identifier: id,
                descriptor: descriptor,
                rootDirectory: themeDir,
                assetsDirectory: assetsDir
            )
        }
        throw ThemeLoaderError.manifestNotFound(themeID: id)
    }

    private func resolveAssetsDirectory(in themeDir: URL) -> URL {
        for candidate in assetSubdirectories {
            let resolved = candidate == "." ? themeDir : themeDir.appending(path: candidate, directoryHint: .isDirectory)
            if fileManager.fileExists(atPath: resolved.path) {
                return resolved
            }
        }
        return themeDir
    }

    private func themeDirectories(in root: URL) -> [URL] {
        guard fileManager.fileExists(atPath: root.path) else { return [] }
        guard let contents = try? fileManager.contentsOfDirectory(
            at: root,
            includingPropertiesForKeys: [.isDirectoryKey],
            options: [.skipsHiddenFiles]
        ) else {
            return []
        }
        return contents.filter { url in
            (try? url.resourceValues(forKeys: [.isDirectoryKey]).isDirectory) == true
        }
    }

    private func loadDescriptor(at url: URL) throws -> ThemeDescriptor {
        let data: Data
        do {
            data = try Data(contentsOf: url)
        } catch {
            throw ThemeLoaderError.manifestUnreadable(themeID: url.deletingLastPathComponent().lastPathComponent, message: "\(error)")
        }
        do {
            return try JSONDecoder().decode(ThemeDescriptor.self, from: data)
        } catch {
            throw ThemeLoaderError.manifestInvalidJSON(themeID: url.deletingLastPathComponent().lastPathComponent, message: "\(error)")
        }
    }
}
