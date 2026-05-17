import Foundation
import KiriFriendsCore

public struct BuddyAssetLibrary {
    private let rootDirectory: URL
    private let fileManager: FileManager

    public init(
        rootDirectory: URL,
        fileManager: FileManager = .default
    ) {
        self.rootDirectory = rootDirectory
        self.fileManager = fileManager
    }

    public func importPack(from packDirectory: URL) throws -> BuddyAssetManifest {
        let manifest = try loadManifest(from: packDirectory)
        try BuddyAssetValidator.validate(manifest: manifest, in: packDirectory)

        let destination = rootDirectory.appending(path: manifest.identifier, directoryHint: .isDirectory)
        try fileManager.createDirectory(at: rootDirectory, withIntermediateDirectories: true)
        if fileManager.fileExists(atPath: destination.path) {
            try fileManager.removeItem(at: destination)
        }
        try fileManager.copyItem(at: packDirectory, to: destination)
        return manifest
    }

    public func installedManifests() throws -> [BuddyAssetManifest] {
        guard fileManager.fileExists(atPath: rootDirectory.path) else { return [] }

        let packs = try fileManager.contentsOfDirectory(
            at: rootDirectory,
            includingPropertiesForKeys: nil,
            options: [.skipsHiddenFiles]
        )

        return packs.compactMap { try? loadManifest(from: $0) }
            .sorted { $0.displayName < $1.displayName }
    }

    public func packDirectory(for manifest: BuddyAssetManifest) -> URL {
        rootDirectory.appending(path: manifest.identifier, directoryHint: .isDirectory)
    }

    private func loadManifest(from packDirectory: URL) throws -> BuddyAssetManifest {
        let manifestURL = packDirectory.appending(path: "manifest.json")
        let data = try Data(contentsOf: manifestURL)
        return try KiriJSON.decoder.decode(BuddyAssetManifest.self, from: data)
    }
}

