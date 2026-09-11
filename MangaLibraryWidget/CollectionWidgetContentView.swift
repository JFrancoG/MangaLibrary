import CoreGraphics
import Foundation
import SwiftUI
import WidgetKit

struct CollectionWidgetContentView: View {
    let item: CollectionWidgetSnapshot.Item
    let cover: CGImage?
    let totalMangaCount: Int
    let generatedAt: Date
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            CollectionWidgetHeaderView(totalMangaCount: totalMangaCount)
            Spacer(minLength: dynamicTypeSize.isAccessibilitySize ? 0 : 4)
            CollectionWidgetRowView(item: item, cover: cover)
            Spacer(minLength: dynamicTypeSize.isAccessibilitySize ? 0 : 4)
            CollectionWidgetFooterView(generatedAt: generatedAt)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }
}

#if DEBUG
#Preview("Collection content", as: .systemMedium) {
    ReadingWidgetComponentPreview(component: .collectionWidgetContent, locale: Locale(identifier: "es"))
} timeline: {
    CollectionWidgetPreview.content
}
#endif
