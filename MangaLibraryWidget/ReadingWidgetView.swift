import SwiftUI
import WidgetKit

struct ReadingWidgetView: View {
    let entry: ReadingWidgetEntry

    @Environment(\.widgetFamily) private var family

    var body: some View {
        Group {
            switch entry.state {
            case let .snapshot(snapshot):
                if family == .systemMedium {
                    ReadingWidgetStatusView(state: .unavailable, content: .collection)
                } else if snapshot.state == .empty {
                    ReadingWidgetStatusView(state: .empty, statusIllustration: entry.statusIllustration)
                } else {
                    ReadingWidgetContentView(
                        snapshot: snapshot,
                        items: entry.items,
                        covers: entry.covers,
                        maximumItemCount: maximumItemCount,
                        usesCompactProgress: family == .systemSmall
                    )
                }
            case let .collection(snapshot, generatedAt):
                if family != .systemMedium {
                    ReadingWidgetStatusView(state: .unavailable)
                } else if snapshot.items.isEmpty {
                    ReadingWidgetStatusView(
                        state: .empty,
                        content: .collection,
                        statusIllustration: entry.statusIllustration
                    )
                } else if let item = entry.collectionItem {
                    CollectionWidgetContentView(
                        item: item,
                        cover: item.coverResourceID.flatMap { entry.covers[$0] },
                        totalMangaCount: snapshot.items.count,
                        generatedAt: generatedAt
                    )
                } else {
                    ReadingWidgetStatusView(state: .unavailable, content: .collection)
                }
            case .redacted:
                ReadingWidgetStatusView(
                    state: .redacted,
                    content: statusContent,
                    statusIllustration: entry.statusIllustration
                )
            case .unavailable:
                ReadingWidgetStatusView(
                    state: .unavailable,
                    content: statusContent,
                    statusIllustration: entry.statusIllustration
                )
            }
        }
        .foregroundStyle(.textPrimary)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .privacySensitive()
    }

    private var statusContent: ReadingWidgetStatusView.Content {
        family == .systemMedium ? .collection : .reading
    }

    private var maximumItemCount: Int {
        switch family {
        case .systemLarge: 6
        case .systemMedium: 3
        default: 1
        }
    }
}

#if DEBUG
#Preview("Collection widget", as: .systemMedium) {
    ReadingWidgetComponentPreview(component: .readingWidget)
} timeline: {
    CollectionWidgetPreview.content
}
#endif
