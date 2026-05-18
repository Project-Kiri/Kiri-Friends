import Foundation

public struct BuddyAnimationFrameManifest: Codable, Hashable, Sendable {
    public var schemaVersion: Int
    public var theme: String
    public var sourceFile: String
    public var sourceSha256: String
    public var durationMs: Int
    public var frameSize: Int
    public var frames: [String]
    public var posterFrame: String
    public var layout: BuddyAnimationLayout

    public init(
        schemaVersion: Int = 1,
        theme: String,
        sourceFile: String,
        sourceSha256: String,
        durationMs: Int,
        frameSize: Int,
        frames: [String],
        posterFrame: String,
        layout: BuddyAnimationLayout
    ) {
        self.schemaVersion = schemaVersion
        self.theme = theme
        self.sourceFile = sourceFile
        self.sourceSha256 = sourceSha256
        self.durationMs = durationMs
        self.frameSize = frameSize
        self.frames = frames
        self.posterFrame = posterFrame
        self.layout = layout
    }
}

public enum BuddyAnimationFrameCatalog {
    public static func manifest(for request: BuddyAnimationRequest) -> BuddyAnimationFrameManifest? {
        manifest(for: request, bundle: .module)
    }

    public static func frameURL(
        named frameName: String,
        for request: BuddyAnimationRequest
    ) -> URL? {
        frameURL(named: frameName, for: request, bundle: .module)
    }

    static func manifest(
        for request: BuddyAnimationRequest,
        bundle: Bundle
    ) -> BuddyAnimationFrameManifest? {
        let subdirectory = resourceSubdirectory(for: request)
        guard let url = bundle.url(
            forResource: "manifest",
            withExtension: "json",
            subdirectory: subdirectory
        ) else {
            return nil
        }

        guard let data = try? Data(contentsOf: url) else { return nil }
        return try? JSONDecoder().decode(BuddyAnimationFrameManifest.self, from: data)
    }

    static func frameURL(
        named frameName: String,
        for request: BuddyAnimationRequest,
        bundle: Bundle
    ) -> URL? {
        bundle.url(
            forResource: frameName.removingPathExtension,
            withExtension: frameName.pathExtension,
            subdirectory: resourceSubdirectory(for: request)
        )
    }

    private static func resourceSubdirectory(for request: BuddyAnimationRequest) -> String {
        "BuddyAnimationFrames/\(request.themeNamespace)/\(request.frameDirectoryName)"
    }
}

private extension String {
    var pathExtension: String {
        guard let dotIndex = lastIndex(of: ".") else { return "" }
        return String(self[index(after: dotIndex)...])
    }

    var removingPathExtension: String {
        guard let dotIndex = lastIndex(of: ".") else { return self }
        return String(self[..<dotIndex])
    }
}
