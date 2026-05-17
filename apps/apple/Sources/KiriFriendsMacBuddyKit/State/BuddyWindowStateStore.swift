// BuddyWindowStateStore.swift
// Persists the buddy window's position so it remembers where the user
// dropped it across app launches. Ports the upstream behaviour in
// `.workspace/reference/clawd-on-desk/src/drag-position.js` plus the
// position-write path in `pet-window-runtime.js`.

import Foundation

public struct BuddyWindowState: Codable, Sendable, Hashable {
    public var originX: Double
    public var originY: Double
    public var displayIdentifier: UInt32?
    public var lastSavedAt: Date

    public init(
        originX: Double,
        originY: Double,
        displayIdentifier: UInt32? = nil,
        lastSavedAt: Date = Date()
    ) {
        self.originX = originX
        self.originY = originY
        self.displayIdentifier = displayIdentifier
        self.lastSavedAt = lastSavedAt
    }
}

public actor BuddyWindowStateStore {
    public static let filename = "buddy-window.json"

    private let fileManager: FileManager
    private let supportDirectory: URL
    private let fileURL: URL

    public init(
        homeDirectory: URL = FileManager.default.homeDirectoryForCurrentUser,
        fileManager: FileManager = .default
    ) {
        self.fileManager = fileManager
        let dir = MacBuddyKit.defaultSupportDirectory(homeDirectory: homeDirectory)
        self.supportDirectory = dir
        self.fileURL = dir.appending(path: Self.filename, directoryHint: .notDirectory)
    }

    public func load() -> BuddyWindowState? {
        guard let data = try? Data(contentsOf: fileURL) else { return nil }
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return try? decoder.decode(BuddyWindowState.self, from: data)
    }

    public func save(_ state: BuddyWindowState) {
        try? fileManager.createDirectory(at: supportDirectory, withIntermediateDirectories: true)
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        guard let data = try? encoder.encode(state) else { return }
        try? data.write(to: fileURL, options: [.atomic])
    }
}
