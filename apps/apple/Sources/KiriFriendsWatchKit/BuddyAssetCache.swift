import Foundation
import KiriFriendsCore

public struct BuddyAssetCache {
    private let rootDirectory: URL
    private let fileManager: FileManager

    public init(rootDirectory: URL, fileManager: FileManager = .default) {
        self.rootDirectory = rootDirectory
        self.fileManager = fileManager
    }

    public func saveReceivedPack(at temporaryURL: URL, manifest: BuddyAssetManifest) throws {
        try BuddyAssetValidator.validate(manifest: manifest, in: temporaryURL)
        try fileManager.createDirectory(at: rootDirectory, withIntermediateDirectories: true)

        let destination = directory(for: manifest)
        if fileManager.fileExists(atPath: destination.path) {
            try fileManager.removeItem(at: destination)
        }
        try fileManager.copyItem(at: temporaryURL, to: destination)
    }

    public func activeManifest(preferredIdentifier: String?) -> BuddyAssetManifest {
        guard let preferredIdentifier,
              let manifest = loadManifest(identifier: preferredIdentifier) else {
            return .fallback
        }
        return manifest
    }

    public func directory(for manifest: BuddyAssetManifest) -> URL {
        rootDirectory.appending(path: manifest.identifier, directoryHint: .isDirectory)
    }

    private func loadManifest(identifier: String) -> BuddyAssetManifest? {
        let manifestURL = rootDirectory
            .appending(path: identifier, directoryHint: .isDirectory)
            .appending(path: "manifest.json")
        guard let data = try? Data(contentsOf: manifestURL) else { return nil }
        return try? KiriJSON.decoder.decode(BuddyAssetManifest.self, from: data)
    }
}

private extension BuddyAssetManifest {
    static let fallback = BuddyAssetManifest(
        identifier: "com.kirifriends.fallback",
        displayName: "Kiri",
        version: "1.0.0",
        states: Dictionary(
            uniqueKeysWithValues: BuddyPersonaState.allCases.map { state in
                (state, ["\(state.rawValue).symbol"])
            }
        )
    )
}
