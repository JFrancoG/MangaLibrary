import SwiftUI
import WidgetKit

#if DEBUG
struct ReadingWidgetLayoutPreview: Widget {
    let locale: Locale
    let textSize: DynamicTypeSize
    var contentWidth: CGFloat? = nil

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: "ReadingLayoutPreview", provider: ReadingWidgetProvider()) { entry in
            ReadingWidgetView(entry: entry)
                .frame(width: contentWidth)
                .environment(\.locale, locale)
                .environment(\.dynamicTypeSize, textSize)
                .containerBackground(.canvas, for: .widget)
        }
        .supportedFamilies([.systemSmall, .systemMedium, .systemLarge])
    }
}

extension ReadingWidgetLayoutPreview {
    init() {
        locale = Locale(identifier: "en")
        textSize = .large
    }
}

#Preview("Small · EN · Light", as: .systemSmall) {
    ReadingWidgetLayoutPreview(locale: Locale(identifier: "en"), textSize: .large)
} timeline: {
    ReadingWidgetPreview.content
}

#Preview("Reading · Small · EN · AX 5", as: .systemSmall) {
    ReadingWidgetLayoutPreview(locale: Locale(identifier: "en"), textSize: .accessibility5)
} timeline: {
    ReadingWidgetPreview.unknownTotal
    ReadingWidgetPreview.empty
    ReadingWidgetPreview.redacted
    ReadingWidgetPreview.unavailable.preparingStatusIllustration(for: .systemSmall)
}

#Preview("Collection · Medium · EN · AX 5", as: .systemMedium) {
    ReadingWidgetLayoutPreview(locale: Locale(identifier: "en"), textSize: .accessibility5)
} timeline: {
    CollectionWidgetPreview.unknownTotal
    CollectionWidgetPreview.completed
    CollectionWidgetPreview.largeCounts
    CollectionWidgetPreview.empty
    CollectionWidgetPreview.redacted
    CollectionWidgetPreview.unavailable.preparingStatusIllustration(for: .systemMedium)
    CollectionWidgetPreview.maximumCollection
    CollectionWidgetPreview.oneOwned
}

#Preview("Medium · ES · XXX Large", as: .systemMedium) {
    ReadingWidgetLayoutPreview(locale: Locale(identifier: "es"), textSize: .xxxLarge)
} timeline: {
    CollectionWidgetPreview.longTitle
    CollectionWidgetPreview.largeCounts
}

#Preview("Large · EN · Standard", as: .systemLarge) {
    ReadingWidgetLayoutPreview(locale: Locale(identifier: "en"), textSize: .large)
} timeline: {
    ReadingWidgetPreview.collection
    ReadingWidgetPreview.rotatedCollection
}

#Preview("Large · ES · XXX Large", as: .systemLarge) {
    ReadingWidgetLayoutPreview(locale: Locale(identifier: "es"), textSize: .xxxLarge)
} timeline: {
    ReadingWidgetPreview.collection
    ReadingWidgetPreview.longTitles
}

#Preview("Large · EN · AX 5", as: .systemLarge) {
    ReadingWidgetLayoutPreview(locale: Locale(identifier: "en"), textSize: .accessibility5)
} timeline: {
    ReadingWidgetPreview.collection
    ReadingWidgetPreview.unknownTotal
    ReadingWidgetPreview.empty
    ReadingWidgetPreview.redacted
    ReadingWidgetPreview.unavailable.preparingStatusIllustration(for: .systemLarge)
}

#Preview("Small · ES · Compact progress", as: .systemSmall) {
    ReadingWidgetLayoutPreview(locale: Locale(identifier: "es"), textSize: .large)
} timeline: {
    ReadingWidgetPreview.compactKnownProgress
    ReadingWidgetPreview.compactUnknownProgress
}

#Preview("Small · EN · Compact AX 5", as: .systemSmall) {
    ReadingWidgetLayoutPreview(locale: Locale(identifier: "en"), textSize: .accessibility5)
} timeline: {
    ReadingWidgetPreview.compactKnownProgress
    ReadingWidgetPreview.compactUnknownProgress
}

#Preview("Large · EN · Complete counts 1–6", as: .systemLarge) {
    ReadingWidgetLayoutPreview(locale: Locale(identifier: "en"), textSize: .large)
} timeline: {
    ReadingWidgetPreview.oneReading
    ReadingWidgetPreview.twoReadings
    ReadingWidgetPreview.threeReadings
    ReadingWidgetPreview.fourReadings
    ReadingWidgetPreview.fiveReadings
    ReadingWidgetPreview.sixReadings
}

#Preview("Large · ES · Long titles · XXX Large", as: .systemLarge) {
    ReadingWidgetLayoutPreview(locale: Locale(identifier: "es"), textSize: .xxxLarge)
} timeline: {
    ReadingWidgetPreview.compactKnownProgress
    ReadingWidgetPreview.threeLongReadings
    ReadingWidgetPreview.fourReadings
}

#Preview("Large · EN · Complete counts · AX 5", as: .systemLarge) {
    ReadingWidgetLayoutPreview(locale: Locale(identifier: "en"), textSize: .accessibility5)
} timeline: {
    ReadingWidgetPreview.oneReading
    ReadingWidgetPreview.fourReadings
    ReadingWidgetPreview.collection
}

#Preview("Large · EN · Partial snapshots", as: .systemLarge) {
    ReadingWidgetLayoutPreview(locale: Locale(identifier: "en"), textSize: .large)
} timeline: {
    ReadingWidgetPreview.partialOneReading
    ReadingWidgetPreview.partialFourReadings
}

#Preview("Collection · Medium · ES · Standard", as: .systemMedium) {
    ReadingWidgetLayoutPreview(locale: Locale(identifier: "es"), textSize: .large)
} timeline: {
    CollectionWidgetPreview.content
    CollectionWidgetPreview.completed
    CollectionWidgetPreview.unknownTotal
    CollectionWidgetPreview.zeroOwned
    CollectionWidgetPreview.oneOwned
}

#Preview("Collection · Medium · ES · AX 5", as: .systemMedium) {
    ReadingWidgetLayoutPreview(locale: Locale(identifier: "es"), textSize: .accessibility5)
} timeline: {
    CollectionWidgetPreview.longTitle
    CollectionWidgetPreview.unknownTotal
    CollectionWidgetPreview.largeCounts
    CollectionWidgetPreview.maximumCollection
    CollectionWidgetPreview.oneOwned
}

#Preview("Large · ES · Enlarged counts · XXX Large", as: .systemLarge) {
    ReadingWidgetLayoutPreview(locale: Locale(identifier: "es"), textSize: .xxxLarge)
} timeline: {
    ReadingWidgetPreview.compactKnownProgress
    ReadingWidgetPreview.fiveReadings
    ReadingWidgetPreview.sixReadings
}

#Preview("Large · ES · Enlarged counts · AX 5", as: .systemLarge) {
    ReadingWidgetLayoutPreview(locale: Locale(identifier: "es"), textSize: .accessibility5)
} timeline: {
    ReadingWidgetPreview.oneReading
    ReadingWidgetPreview.fiveReadings
    ReadingWidgetPreview.sixReadings
}

#Preview("Large · ES · Five and six readings", as: .systemLarge) {
    ReadingWidgetLayoutPreview(locale: Locale(identifier: "es"), textSize: .large)
} timeline: {
    ReadingWidgetPreview.fiveReadings
    ReadingWidgetPreview.sixReadings
    ReadingWidgetPreview.fiveLongReadings
    ReadingWidgetPreview.sixLongReadings
}

#Preview("Large · EN · Five and six long titles", as: .systemLarge) {
    ReadingWidgetLayoutPreview(locale: Locale(identifier: "en"), textSize: .large)
} timeline: {
    ReadingWidgetPreview.fiveLongReadings
    ReadingWidgetPreview.sixLongReadings
}

#Preview("Collection · ES · Header counts", as: .systemMedium) {
    ReadingWidgetLayoutPreview(locale: Locale(identifier: "es"), textSize: .large)
} timeline: {
    CollectionWidgetPreview.completed
    CollectionWidgetPreview.twentyFourManga
    CollectionWidgetPreview.maximumCollection
}

#Preview("Collection · EN · Header counts", as: .systemMedium) {
    ReadingWidgetLayoutPreview(locale: Locale(identifier: "en"), textSize: .large)
} timeline: {
    CollectionWidgetPreview.completed
    CollectionWidgetPreview.twentyFourManga
    CollectionWidgetPreview.maximumCollection
}

#Preview("Collection · ES · Header counts · XXX Large", as: .systemMedium) {
    ReadingWidgetLayoutPreview(locale: Locale(identifier: "es"), textSize: .xxxLarge)
} timeline: {
    CollectionWidgetPreview.completed
    CollectionWidgetPreview.twentyFourManga
    CollectionWidgetPreview.maximumCollection
}

#Preview("Collection · EN · Header counts · XXX Large", as: .systemMedium) {
    ReadingWidgetLayoutPreview(locale: Locale(identifier: "en"), textSize: .xxxLarge)
} timeline: {
    CollectionWidgetPreview.completed
    CollectionWidgetPreview.twentyFourManga
    CollectionWidgetPreview.maximumCollection
}

#Preview("Collection · ES · Header counts · AX 5", as: .systemMedium) {
    ReadingWidgetLayoutPreview(locale: Locale(identifier: "es"), textSize: .accessibility5)
} timeline: {
    CollectionWidgetPreview.completed
    CollectionWidgetPreview.twentyFourManga
    CollectionWidgetPreview.maximumCollection
}

#Preview("Collection · EN · Header counts · AX 5", as: .systemMedium) {
    ReadingWidgetLayoutPreview(locale: Locale(identifier: "en"), textSize: .accessibility5)
} timeline: {
    CollectionWidgetPreview.completed
    CollectionWidgetPreview.twentyFourManga
    CollectionWidgetPreview.maximumCollection
}

#Preview("Collection · ES · Narrow header · AX 5", as: .systemMedium) {
    ReadingWidgetLayoutPreview(locale: Locale(identifier: "es"), textSize: .accessibility5, contentWidth: 220)
} timeline: {
    CollectionWidgetPreview.maximumCollection
}
#endif
