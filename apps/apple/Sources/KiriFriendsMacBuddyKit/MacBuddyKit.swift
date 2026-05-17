// MacBuddyKit.swift
// Umbrella header for the Mac Buddy library. Concrete subsystems
// (state store, HTTP server, agent registry, theme loader) are added
// per phase of the Clawd-on-Desk SwiftUI port.

import Foundation

public enum MacBuddyKit {
    public static let schemaVersion: Int = 1

    public static let defaultBridgePort: UInt16 = 7474

    public static let runtimeFileName: String = "runtime.json"

    public static let supportDirectoryName: String = ".kirifriends"

    public static func defaultSupportDirectory(
        homeDirectory: URL = FileManager.default.homeDirectoryForCurrentUser
    ) -> URL {
        homeDirectory.appending(path: supportDirectoryName, directoryHint: .isDirectory)
    }
}
