import Foundation
import WidgetKit

/// Reads one authorized snapshot per opportunity and resumes its bounded presentation cycle.
///
/// Scheduled entries share prepared covers. WidgetKit owns the actual display and renewal times;
/// publication events can request an earlier reload after a reading or its authorization changes.
struct ReadingWidgetProvider: TimelineProvider {
    private let readEntry: @Sendable (WidgetFamily) -> ReadingWidgetEntry

    func placeholder(in context: Context) -> ReadingWidgetEntry {
        switch context.family {
        case .systemMedium: CollectionWidgetPreview.content
        case .systemLarge: ReadingWidgetPreview.collection
        default: ReadingWidgetPreview.content
        }
    }

    func getSnapshot(in context: Context, completion: @escaping (ReadingWidgetEntry) -> Void) {
        let entry = context.isPreview ? placeholder(in: context) : readEntry(context.family)
        completion(entry.preparingStatusIllustration(for: context.family))
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<ReadingWidgetEntry>) -> Void) {
        let entry = readEntry(context.family).preparingStatusIllustration(for: context.family)
        let dates: [Date]
        switch entry.state {
        case let .snapshot(snapshot):
            dates = ReadingWidgetRotation(snapshot: snapshot).timelineDates(at: entry.date)
        case let .collection(snapshot, generatedAt):
            dates = CollectionWidgetRotation(snapshot: snapshot, generatedAt: generatedAt).timelineDates(at: entry.date)
        case .redacted, .unavailable:
            dates = [entry.date]
        }
        let entries = dates.map {
            ReadingWidgetEntry(
                date: $0,
                state: entry.state,
                covers: entry.covers,
                statusIllustration: entry.statusIllustration
            )
        }
        completion(Timeline(entries: entries, policy: entries.count > 1 ? .atEnd : .never))
    }
}

extension ReadingWidgetProvider {
    init(
        loadEntry: @escaping @Sendable (WidgetFamily) -> ReadingWidgetEntry = { ReadingWidgetEntry.loadLive(family: $0) }
    ) {
        readEntry = loadEntry
    }
}
