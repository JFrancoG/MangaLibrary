import SwiftUI
import WidgetKit

struct MangaLibraryWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: ReadingWidgetBridge.kind, provider: ReadingWidgetProvider()) { entry in
            ReadingWidgetView(entry: entry)
                .containerBackground(.canvas, for: .widget)
        }
        .configurationDisplayName("Manga Library")
        .description("Small and large show your reading. Medium shows your collection.")
        .supportedFamilies([.systemSmall, .systemMedium, .systemLarge])
    }
}

#Preview("Reading · Small states", as: .systemSmall) {
    MangaLibraryWidget()
} timeline: {
    ReadingWidgetPreview.content
    ReadingWidgetPreview.empty
    ReadingWidgetPreview.redacted
    ReadingWidgetPreview.unavailable.preparingStatusIllustration(for: .systemSmall)
    ReadingWidgetPreview.unknownTotal
    ReadingWidgetPreview.shortTitle
}

#Preview("Collection · Medium states", as: .systemMedium) {
    MangaLibraryWidget()
} timeline: {
    CollectionWidgetPreview.content
    CollectionWidgetPreview.rotated
    CollectionWidgetPreview.completed
    CollectionWidgetPreview.longTitle
    CollectionWidgetPreview.empty
    CollectionWidgetPreview.redacted
    CollectionWidgetPreview.unavailable.preparingStatusIllustration(for: .systemMedium)
    CollectionWidgetPreview.unknownTotal
    CollectionWidgetPreview.zeroOwned
}

#Preview("Reading · Large states and rotation", as: .systemLarge) {
    MangaLibraryWidget()
} timeline: {
    ReadingWidgetPreview.collection
    ReadingWidgetPreview.rotatedCollection
    ReadingWidgetPreview.longTitles
    ReadingWidgetPreview.empty
    ReadingWidgetPreview.redacted
    ReadingWidgetPreview.unavailable.preparingStatusIllustration(for: .systemLarge)
}
