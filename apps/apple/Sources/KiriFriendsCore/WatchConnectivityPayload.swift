import Foundation

public enum WatchPayloadKind: String, Codable, Hashable, Sendable {
    case stateSnapshot = "state.snapshot"
    case watchAction = "watch.action"
    case buddySettings = "buddy.settings"
    case healthSignalSummary = "health.signal.summary"
}

public enum WatchConnectivityPayload {
    public static func dictionary<T: Encodable>(from value: T) throws -> [String: Any] {
        let data = try KiriJSON.encoder.encode(value)
        let object = try JSONSerialization.jsonObject(with: data)
        guard let dictionary = object as? [String: Any] else {
            throw WatchConnectivityPayloadError.notDictionary
        }
        return dictionary
    }

    public static func decode<T: Decodable>(_ type: T.Type, from dictionary: [String: Any]) throws -> T {
        let data = try JSONSerialization.data(withJSONObject: dictionary)
        return try KiriJSON.decoder.decode(type, from: data)
    }
}

public enum WatchConnectivityPayloadError: Error, Hashable, Sendable {
    case notDictionary
}

/// Lightweight envelope namespace that lets the phone bundle several
/// payloads (state snapshot + buddy settings + heartbeat) into a single
/// WatchConnectivity `applicationContext`. The format keeps each payload
/// under its `WatchPayloadKind.rawValue` slot so the watch can dispatch
/// without one overwriting another.
///
/// Wire shape:
///
/// ```json
/// {
///   "state.snapshot": { ... snapshot fields ... },
///   "buddy.settings": { ... settings fields ... }
/// }
/// ```
///
/// Backwards compatibility: when the context has a top-level `kind`
/// field, callers should fall back to single-payload decoding. The
/// helpers below handle both shapes.
public enum WatchConnectivityEnvelope {
    /// Builds an envelope dictionary suitable for
    /// `WCSession.updateApplicationContext`. Pass an existing context to
    /// merge instead of replace.
    public static func merge<T: Encodable>(
        kind: WatchPayloadKind,
        value: T,
        into existing: [String: Any]
    ) throws -> [String: Any] {
        let payload = try WatchConnectivityPayload.dictionary(from: value)
        var next = sanitize(existing)
        next[kind.rawValue] = payload
        return next
    }

    /// Returns the kind/payload pairs nested in `context`. When the
    /// dictionary is a legacy single-payload context (carries a
    /// top-level `kind` key), the function returns a single pair so
    /// callers handle both shapes uniformly.
    public static func unpack(_ context: [String: Any]) -> [(kind: WatchPayloadKind, payload: [String: Any])] {
        if let kindRaw = context["kind"] as? String,
           let kind = WatchPayloadKind(rawValue: kindRaw)
        {
            return [(kind, context)]
        }

        var result: [(kind: WatchPayloadKind, payload: [String: Any])] = []
        for (key, value) in context {
            guard let kind = WatchPayloadKind(rawValue: key) else { continue }
            guard let payload = value as? [String: Any] else { continue }
            result.append((kind, payload))
        }
        return result
    }

    /// Strips entries that no longer belong in an envelope-shaped
    /// context. Anything outside of the documented `WatchPayloadKind`
    /// slots is discarded so legacy callers cannot leave stale top-level
    /// keys behind.
    private static func sanitize(_ context: [String: Any]) -> [String: Any] {
        var sanitized: [String: Any] = [:]
        for (key, value) in context {
            guard WatchPayloadKind(rawValue: key) != nil else { continue }
            guard let payload = value as? [String: Any] else { continue }
            sanitized[key] = payload
        }
        return sanitized
    }
}
