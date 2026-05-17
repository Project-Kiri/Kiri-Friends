import Foundation

public enum BuddyAssetValidator {
    public static func validate(manifest: BuddyAssetManifest, in packDirectory: URL) throws {
        let missingStates = manifest.missingRequiredStates
        guard missingStates.isEmpty else {
            throw BuddyAssetValidationError.missingStates(missingStates)
        }

        for fileName in manifest.states.values.flatMap({ $0 }) {
            let fileURL = packDirectory.appending(path: fileName)
            guard FileManager.default.fileExists(atPath: fileURL.path) else {
                throw BuddyAssetValidationError.missingFile(fileName)
            }
        }
    }
}

public enum BuddyAssetValidationError: Error, Hashable, Sendable {
    case missingStates([BuddyPersonaState])
    case missingFile(String)
}
