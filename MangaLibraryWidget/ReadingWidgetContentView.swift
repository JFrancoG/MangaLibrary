import CoreGraphics
import SwiftUI
import WidgetKit

struct ReadingWidgetContentView: View {
    let snapshot: ReadingSnapshot
    let items: [ReadingSnapshot.Item]
    let covers: [String: CGImage]
    let maximumItemCount: Int
    var usesCompactProgress = false
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    var body: some View {
        ViewThatFits(in: .vertical) {
            if let expandedRowStyle {
                if itemCount >= 5 {
                    ReadingWidgetListView(
                        snapshot: snapshot,
                        items: items,
                        covers: covers,
                        visibleCount: itemCount,
                        rowStyle: expandedRowStyle,
                        usesLargerRows: true
                    )
                }
                ReadingWidgetListView(
                    snapshot: snapshot,
                    items: items,
                    covers: covers,
                    visibleCount: itemCount,
                    rowStyle: expandedRowStyle
                )
            }
            if itemCount >= 6 {
                ReadingWidgetListView(
                    snapshot: snapshot,
                    items: items,
                    covers: covers,
                    visibleCount: 6
                )
            }
            if itemCount >= 5 {
                ReadingWidgetListView(
                    snapshot: snapshot,
                    items: items,
                    covers: covers,
                    visibleCount: 5
                )
            }
            if itemCount >= 4 {
                ReadingWidgetListView(
                    snapshot: snapshot,
                    items: items,
                    covers: covers,
                    visibleCount: 4
                )
            }
            if itemCount >= 3 {
                ReadingWidgetListView(
                    snapshot: snapshot,
                    items: items,
                    covers: covers,
                    visibleCount: 3
                )
            }
            if itemCount >= 2 {
                ReadingWidgetListView(
                    snapshot: snapshot,
                    items: items,
                    covers: covers,
                    visibleCount: 2
                )
            }
            if maximumItemCount < 6 {
                ReadingWidgetListView(
                    snapshot: snapshot,
                    items: items,
                    covers: covers,
                    visibleCount: 1,
                    rowStyle: .prominent,
                    usesCompactProgress: usesCompactProgress
                )
            }
            ReadingWidgetListView(
                snapshot: snapshot,
                items: items,
                covers: covers,
                visibleCount: 1,
                usesCompactProgress: usesCompactProgress
            )
        }
    }

    private var itemCount: Int { min(maximumItemCount, items.count) }

    private var expandedRowStyle: ReadingWidgetRowView.Style? {
        guard
            maximumItemCount == 6,
            !dynamicTypeSize.isAccessibilitySize,
            snapshot.totalEligibleCount == Int64(snapshot.items.count),
            items.count == snapshot.items.count
        else { return nil }
        return switch items.count {
        case 1: .singleReading
        case 2: .twoReadings
        case 3: .threeReadings
        case 4: .fourReadings
        case 5: .fiveReadings
        case 6: .sixReadings
        default: nil
        }
    }
}

#if DEBUG
#Preview("Reading content", as: .systemLarge) {
    ReadingWidgetComponentPreview(component: .readingWidgetContent)
} timeline: {
    ReadingWidgetPreview.threeReadings
}
#endif
