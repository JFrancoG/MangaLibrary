import SwiftUI
import WidgetKit

struct CollectionWidgetHeaderView: View {
    let totalMangaCount: Int
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    var body: some View {
        ViewThatFits(in: .horizontal) {
            HStack(alignment: .firstTextBaseline, spacing: 8) {
                title.fixedSize()
                Spacer(minLength: 0)
                CollectionWidgetCountBadgeView(totalMangaCount: totalMangaCount)
                    .fixedSize()
            }
            HStack(alignment: .firstTextBaseline, spacing: 8) {
                title
                Spacer(minLength: 0)
                CollectionWidgetCountBadgeView(totalMangaCount: totalMangaCount, showsUnit: false)
                    .fixedSize()
            }
        }
    }

    private var title: some View {
        Text("My collection")
            .font(dynamicTypeSize.isAccessibilitySize ? .caption2.weight(.semibold) : .subheadline.weight(.semibold))
            .foregroundStyle(.brandPrimaryInk)
            .lineLimit(2)
            .fixedSize(horizontal: false, vertical: true)
            .accessibilityAddTraits(.isHeader)
    }
}

#if DEBUG
#Preview("Collection header", as: .systemMedium) {
    ReadingWidgetComponentPreview(component: .collectionWidgetHeader, locale: Locale(identifier: "es"))
} timeline: {
    CollectionWidgetPreview.twentyFourManga
}
#endif
