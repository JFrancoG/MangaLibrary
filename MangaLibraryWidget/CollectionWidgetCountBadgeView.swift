import Foundation
import SwiftUI
import WidgetKit

struct CollectionWidgetCountBadgeView: View {
    let totalMangaCount: Int
    var showsUnit = true
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @Environment(\.locale) private var locale

    var body: some View {
        Group {
            if showsUnit {
                Text(styledTotal)
                    .font(.caption)
            } else {
                Text(totalMangaCount, format: .number.locale(locale))
                    .font(numberFont)
            }
        }
        .lineLimit(1)
        .foregroundStyle(.onBrandContainer)
        .padding(.horizontal, 9)
        .padding(.vertical, dynamicTypeSize.isAccessibilitySize ? 2 : 3)
        .background(.brandContainer, in: .capsule)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text("\(totalMangaCount) manga titles in your collection"))
    }

    private var numberFont: Font {
        dynamicTypeSize.isAccessibilitySize ? .caption.weight(.semibold) : .title3.weight(.semibold)
    }

    private var styledTotal: AttributedString {
        let resource = LocalizedStringResource("**\(totalMangaCount)** manga titles", locale: locale)
        var value = AttributedString(localized: resource)
        for run in value.runs where run.inlinePresentationIntent?.contains(.stronglyEmphasized) == true {
            value[run.range].font = numberFont
        }
        return value
    }
}

#if DEBUG
#Preview("Collection count", as: .systemMedium) {
    ReadingWidgetComponentPreview(component: .collectionWidgetCountBadge, locale: Locale(identifier: "es"))
} timeline: {
    CollectionWidgetPreview.maximumCollection
}
#endif
