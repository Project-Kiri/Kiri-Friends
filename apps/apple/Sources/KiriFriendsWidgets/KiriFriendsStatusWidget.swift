import KiriFriendsCore
import SwiftUI

#if canImport(WidgetKit)
import WidgetKit

struct KiriFriendsStatusEntry: TimelineEntry {
    let date: Date
    let snapshot: ComplicationSnapshot
}

struct KiriFriendsStatusProvider: TimelineProvider {
    func placeholder(in context: Context) -> KiriFriendsStatusEntry {
        KiriFriendsStatusEntry(date: .now, snapshot: .placeholder)
    }

    func getSnapshot(in context: Context, completion: @escaping (KiriFriendsStatusEntry) -> Void) {
        completion(KiriFriendsStatusEntry(date: .now, snapshot: loadSnapshot()))
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<KiriFriendsStatusEntry>) -> Void) {
        // Re-poll the app-group snapshot every 5 minutes; the iPhone
        // companion calls `WidgetCenter.shared.reloadAllTimelines()`
        // whenever it writes a new snapshot, so this interval mostly
        // covers the case where the companion is suspended.
        let entry = KiriFriendsStatusEntry(date: .now, snapshot: loadSnapshot())
        completion(Timeline(entries: [entry], policy: .after(.now.addingTimeInterval(5 * 60))))
    }

    static func runtimeSnapshot(from store: AppGroupSnapshotStore?) -> ComplicationSnapshot {
        guard let snapshot = store?.loadComplicationSnapshot() else { return .empty }
        return snapshot == .placeholder ? .empty : snapshot
    }

    private func loadSnapshot() -> ComplicationSnapshot {
        Self.runtimeSnapshot(from: AppGroupSnapshotStore(suiteName: "group.com.kirifriends.shared"))
    }
}

public struct KiriFriendsStatusWidget: Widget {
    public let kind = "com.kirifriends.status"

    public init() {}

    public var body: some WidgetConfiguration {
        #if os(watchOS)
        configuration.supportedFamilies([
            .accessoryCircular,
            .accessoryCorner,
            .accessoryRectangular,
            .accessoryInline
        ])
        #else
        configuration.supportedFamilies([.systemSmall])
        #endif
    }

    private var configuration: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: KiriFriendsStatusProvider()) { entry in
            KiriFriendsComplicationView(snapshot: entry.snapshot)
        }
        .configurationDisplayName("Kiri Status")
        .description("Shows the current Kiri Friends CLI status.")
    }
}

struct KiriFriendsComplicationView: View {
    let snapshot: ComplicationSnapshot

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Label(snapshot.shortStatus, systemImage: snapshot.symbolName)
                .font(.caption2)
                .lineLimit(1)
            if let detail = snapshot.detail {
                Text(detail)
                    .font(.caption2)
                    .lineLimit(1)
                    .foregroundStyle(.secondary)
            }
        }
        .privacySensitive(snapshot.sensitivity != .none)
    }
}
#endif
