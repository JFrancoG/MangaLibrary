import SwiftUI
import WidgetKit

#if DEBUG
struct ReadingWidgetComponentPreview: Widget {
    enum Component {
        case collectionWidgetContent
        case collectionWidgetCountBadge
        case collectionWidgetFooter
        case collectionWidgetHeader
        case collectionWidgetRow
        case readingWidgetContent
        case readingWidgetList
        case readingWidgetRow
        case readingWidgetStatus
        case readingWidget
    }

    var component: Component = .readingWidget
    var locale = Locale(identifier: "en")

    var body: some WidgetConfiguration {
        StaticConfiguration(
            kind: "ReadingComponentPreview",
            provider: ReadingWidgetProvider { _ in
                CollectionWidgetPreview.content
            }
        ) { entry in
            Group {
                switch component {
                case .collectionWidgetContent:
                    if case let .collection(snapshot, generatedAt) = entry.state, let item = entry.collectionItem {
                        CollectionWidgetContentView(
                            item: item,
                            cover: item.coverResourceID.flatMap { entry.covers[$0] },
                            totalMangaCount: snapshot.items.count,
                            generatedAt: generatedAt
                        )
                    }
                case .collectionWidgetCountBadge:
                    if case let .collection(snapshot, _) = entry.state {
                        CollectionWidgetCountBadgeView(totalMangaCount: snapshot.items.count)
                    }
                case .collectionWidgetFooter:
                    CollectionWidgetFooterView(generatedAt: entry.date)
                case .collectionWidgetHeader:
                    if case let .collection(snapshot, _) = entry.state {
                        CollectionWidgetHeaderView(totalMangaCount: snapshot.items.count)
                    }
                case .collectionWidgetRow:
                    if let item = entry.collectionItem {
                        CollectionWidgetRowView(item: item, cover: item.coverResourceID.flatMap { entry.covers[$0] })
                    }
                case .readingWidgetContent:
                    if case let .snapshot(snapshot) = entry.state {
                        ReadingWidgetContentView(
                            snapshot: snapshot,
                            items: entry.items,
                            covers: entry.covers,
                            maximumItemCount: 6
                        )
                    }
                case .readingWidgetList:
                    if case let .snapshot(snapshot) = entry.state {
                        ReadingWidgetListView(
                            snapshot: snapshot,
                            items: entry.items,
                            covers: entry.covers,
                            visibleCount: 3
                        )
                    }
                case .readingWidgetRow:
                    if let item = entry.items.first {
                        ReadingWidgetRowView(item: item, cover: item.coverResourceID.flatMap { entry.covers[$0] })
                    }
                case .readingWidgetStatus:
                    ReadingWidgetStatusView(state: .redacted, content: .collection)
                case .readingWidget:
                    ReadingWidgetView(entry: entry)
                }
            }
            .environment(\.locale, locale)
            .containerBackground(.canvas, for: .widget)
        }
        .supportedFamilies([.systemSmall, .systemMedium, .systemLarge])
    }
}
#endif
