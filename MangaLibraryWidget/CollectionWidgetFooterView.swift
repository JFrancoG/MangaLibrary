import Foundation
import SwiftUI
import WidgetKit

struct CollectionWidgetFooterView: View {
    let generatedAt: Date
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    var body: some View {
        Group {
            if dynamicTypeSize.isAccessibilitySize {
                Text(generatedAt, format: .dateTime.day().month(.twoDigits).year(.twoDigits))
            } else {
                Text("Updated \(generatedAt, format: .dateTime.month(.twoDigits).day().hour().minute())")
            }
        }
        .font(.caption2)
        .foregroundStyle(.textSecondary)
        .frame(maxWidth: .infinity, alignment: .trailing)
        .lineLimit(1)
        .accessibilityLabel(Text("Updated \(generatedAt, format: .dateTime.month(.twoDigits).day().hour().minute())"))
    }
}

#if DEBUG
#Preview("Collection update date", as: .systemMedium) {
    ReadingWidgetComponentPreview(component: .collectionWidgetFooter, locale: Locale(identifier: "es"))
} timeline: {
    CollectionWidgetPreview.content
}
#endif
