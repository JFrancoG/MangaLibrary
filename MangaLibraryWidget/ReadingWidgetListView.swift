import CoreGraphics
import SwiftUI

struct ReadingWidgetListView: View {
    let snapshot: ReadingSnapshot
    let items: [ReadingSnapshot.Item]
    let covers: [String: CGImage]
    let visibleCount: Int
    var rowStyle = ReadingWidgetRowView.Style.compact
    var usesCompactProgress = false
    var usesLargerRows = false
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("Reading")
                .font(dynamicTypeSize.isAccessibilitySize ? .caption.weight(.semibold) : .subheadline.weight(.semibold))
                .foregroundStyle(.brandPrimaryInk)
                .frame(maxWidth: .infinity)
                .accessibilityAddTraits(.isHeader)
            Spacer(minLength: dynamicTypeSize.isAccessibilitySize || usesLargerRows ? 0 : 4)
            VStack(alignment: .leading, spacing: usesLargerRows ? 2 : 4) {
                ForEach(items.prefix(visibleCount), id: \.mangaID) { item in
                    ReadingWidgetRowView(
                        item: item,
                        cover: item.coverResourceID.flatMap { covers[$0] },
                        style: rowStyle,
                        usesCompactProgress: usesCompactProgress,
                        usesLargerRows: usesLargerRows
                    )
                }
            }
            Spacer(minLength: dynamicTypeSize.isAccessibilitySize || usesLargerRows ? 0 : 4)
            ReadingWidgetFooterView(snapshot: snapshot, visibleCount: visibleCount)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }
}
