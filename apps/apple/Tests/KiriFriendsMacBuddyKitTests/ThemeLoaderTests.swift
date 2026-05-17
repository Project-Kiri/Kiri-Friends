// ThemeLoaderTests.swift
// Verifies that bundled theme manifests parse and that the loader finds
// the assets directory for each layout convention.

import Foundation
import KiriFriendsMacBuddyKit
import Testing

@Suite("ThemeLoader")
struct ThemeLoaderTests {
    @Test("Loader discovers themes inside a directory")
    func discoversBundledThemes() async throws {
        let layout = try makeBundleLayout()
        defer { try? FileManager.default.removeItem(at: layout.root) }

        let loader = ThemeLoader(searchRoots: [layout.root])
        let themes = await loader.availableThemes()
        let names = themes.map(\.identifier).sorted()
        #expect(names == ["mockA", "mockB"])
    }

    @Test("Loader resolves the asset directory for nested svg/ layout")
    func resolvesNestedSvgLayout() async throws {
        let layout = try makeBundleLayout()
        defer { try? FileManager.default.removeItem(at: layout.root) }

        let loader = ThemeLoader(searchRoots: [layout.root])
        let theme = try await loader.theme(withIdentifier: "mockA")
        #expect(theme.assetsDirectory.lastPathComponent == "svg")
    }

    @Test("Loader falls back to assets/ when svg/ is missing")
    func fallsBackToAssetsLayout() async throws {
        let layout = try makeBundleLayout()
        defer { try? FileManager.default.removeItem(at: layout.root) }

        let loader = ThemeLoader(searchRoots: [layout.root])
        let theme = try await loader.theme(withIdentifier: "mockB")
        #expect(theme.assetsDirectory.lastPathComponent == "assets")
    }

    @Test("Loader returns manifestNotFound for unknown themes")
    func unknownThemeErrors() async throws {
        let layout = try makeBundleLayout()
        defer { try? FileManager.default.removeItem(at: layout.root) }

        let loader = ThemeLoader(searchRoots: [layout.root])
        do {
            _ = try await loader.theme(withIdentifier: "missing")
            Issue.record("Expected manifestNotFound")
        } catch {
            switch error {
            case ThemeLoaderError.manifestNotFound:
                break
            default:
                Issue.record("Unexpected error: \(error)")
            }
        }
    }

    @Test("ThemeDescriptor#primaryFile falls back to a known state")
    func primaryFileFallback() {
        let descriptor = ThemeDescriptor(
            schemaVersion: 1,
            name: "Test",
            version: "0.1.0",
            states: [
                "idle": ["idle.svg"],
                "working": ["working.svg"],
            ]
        )
        #expect(descriptor.primaryFile(for: .working) == "working.svg")
        #expect(descriptor.primaryFile(for: .juggling) == "working.svg")
        #expect(descriptor.primaryFile(for: .error) == "idle.svg")
    }

    // MARK: - helpers

    private struct MockLayout {
        let root: URL
    }

    private func makeBundleLayout() throws -> MockLayout {
        let root = FileManager.default.temporaryDirectory.appending(path: UUID().uuidString, directoryHint: .isDirectory)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)

        let themeA = root.appending(path: "mockA", directoryHint: .isDirectory)
        try FileManager.default.createDirectory(at: themeA.appending(path: "svg", directoryHint: .isDirectory), withIntermediateDirectories: true)
        try writeManifest(at: themeA.appending(path: "theme.json"), name: "Mock A")

        let themeB = root.appending(path: "mockB", directoryHint: .isDirectory)
        try FileManager.default.createDirectory(at: themeB.appending(path: "assets", directoryHint: .isDirectory), withIntermediateDirectories: true)
        try writeManifest(at: themeB.appending(path: "theme.json"), name: "Mock B")

        return MockLayout(root: root)
    }

    private func writeManifest(at url: URL, name: String) throws {
        let manifest = """
        {
          "schemaVersion": 1,
          "name": "\(name)",
          "version": "0.1.0",
          "states": {
            "idle": ["idle.svg"]
          }
        }
        """
        try Data(manifest.utf8).write(to: url)
    }
}
