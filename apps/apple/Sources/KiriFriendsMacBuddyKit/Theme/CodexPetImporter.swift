// CodexPetImporter.swift
// Minimal Codex Pet zip importer. Mirrors the public API of
// `.workspace/reference/clawd-on-desk/src/codex-pet-importer.js` so the
// settings UI in a later phase can route imports through this layer.
// Phase 4 only handles extraction + manifest discovery; atlas → SVG
// conversion is wired in Phase 4 follow-ups when we expand the visual
// resolver.

import Foundation

public enum CodexPetImportError: Error, Sendable {
    case extractionFailed(String)
    case manifestMissing
    case manifestInvalid(String)
}

public struct CodexPetImportResult: Sendable, Hashable {
    public var manifestURL: URL
    public var rootDirectory: URL

    public init(manifestURL: URL, rootDirectory: URL) {
        self.manifestURL = manifestURL
        self.rootDirectory = rootDirectory
    }
}

// FileManager is documented as thread-safe except for the delegate
// channel, which we never set, so `@unchecked Sendable` is the
// pragmatic conformance.
public struct CodexPetImporter: @unchecked Sendable {
    private let fileManager: FileManager
    private let unzipURL: URL

    public init(
        fileManager: FileManager = .default,
        unzipURL: URL = URL(filePath: "/usr/bin/unzip")
    ) {
        self.fileManager = fileManager
        self.unzipURL = unzipURL
    }

    /// Extracts a Codex Pet zip into `destinationParent/<archive-name>/`
    /// and returns the resolved theme directory + manifest URL. The
    /// caller is responsible for moving the result into the live themes
    /// directory once it has validated the manifest.
    public func importZip(at zipURL: URL, intoParent destinationParent: URL) throws -> CodexPetImportResult {
        let archiveName = zipURL.deletingPathExtension().lastPathComponent
        let extractDir = destinationParent.appending(path: archiveName, directoryHint: .isDirectory)
        try fileManager.createDirectory(at: extractDir, withIntermediateDirectories: true)

        let process = Process()
        process.executableURL = unzipURL
        process.arguments = ["-o", zipURL.path, "-d", extractDir.path]
        let stderr = Pipe()
        process.standardError = stderr
        do {
            try process.run()
        } catch {
            throw CodexPetImportError.extractionFailed("\(error)")
        }
        process.waitUntilExit()
        guard process.terminationStatus == 0 else {
            let errorData = stderr.fileHandleForReading.readDataToEndOfFile()
            throw CodexPetImportError.extractionFailed(
                String(data: errorData, encoding: .utf8) ?? "unzip exit code \(process.terminationStatus)"
            )
        }

        let manifestCandidates = [
            extractDir.appending(path: "theme.json"),
            extractDir.appending(path: "manifest.json"),
        ]
        guard let manifestURL = manifestCandidates.first(where: { fileManager.fileExists(atPath: $0.path) }) else {
            throw CodexPetImportError.manifestMissing
        }
        return CodexPetImportResult(manifestURL: manifestURL, rootDirectory: extractDir)
    }
}
