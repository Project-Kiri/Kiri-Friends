import Foundation

public struct AppGroupSnapshotStore {
    private let defaults: UserDefaults
    private let complicationKey = "KiriFriends.complicationSnapshot"

    public init?(suiteName: String) {
        guard let defaults = UserDefaults(suiteName: suiteName) else { return nil }
        self.defaults = defaults
    }

    public init(defaults: UserDefaults) {
        self.defaults = defaults
    }

    public func saveComplicationSnapshot(_ snapshot: ComplicationSnapshot) {
        guard let data = try? KiriJSON.encoder.encode(snapshot) else { return }
        defaults.set(data, forKey: complicationKey)
    }

    public func loadComplicationSnapshot() -> ComplicationSnapshot? {
        guard let data = defaults.data(forKey: complicationKey) else { return nil }
        return try? KiriJSON.decoder.decode(ComplicationSnapshot.self, from: data)
    }
}
