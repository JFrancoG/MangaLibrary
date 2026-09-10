import SwiftUI
import WidgetKit

struct ReadingWidgetFooterView: View {
    let snapshot: ReadingSnapshot
    let visibleCount: Int
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @Environment(\.locale) private var locale

    var body: some View {
        ViewThatFits(in: .horizontal) {
            HStack(alignment: .firstTextBaseline, spacing: 8) {
                remainingReadings
                Spacer(minLength: 8)
                updatedAt
            }
            VStack(alignment: .leading, spacing: 2) {
                remainingReadings
                updatedAt
            }
        }
        .foregroundStyle(.textSecondary)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(footerDescription)
    }

    private var footerDescription: Text {
        if let total = snapshot.totalEligibleCount, total > Int64(visibleCount) {
            Text("\(total - Int64(visibleCount)) more on iPhone. Updated \(formattedUpdateDate)")
        } else {
            Text("Updated \(formattedUpdateDate)")
        }
    }

    private var formattedUpdateDate: String {
        snapshot.generatedAt.formatted(.dateTime.month(.twoDigits).day().hour().minute().locale(locale))
    }

    @ViewBuilder private var remainingReadings: some View {
        if let total = snapshot.totalEligibleCount, total > Int64(visibleCount) {
            Group {
                if dynamicTypeSize.isAccessibilitySize {
                    Text("\(total - Int64(visibleCount)) more")
                } else {
                    Text("\(total - Int64(visibleCount)) more on iPhone")
                }
            }
            .font(dynamicTypeSize.isAccessibilitySize ? .caption2.weight(.medium) : .caption.weight(.medium))
            .lineLimit(1)
            .accessibilityLabel(Text("\(total - Int64(visibleCount)) more on iPhone"))
        }
    }

    private var updatedAt: some View {
        Group {
            if dynamicTypeSize.isAccessibilitySize {
                Text(snapshot.generatedAt, format: .dateTime.day().month(.twoDigits).year(.twoDigits))
            } else {
                ViewThatFits(in: .horizontal) {
                    Text("Updated \(snapshot.generatedAt, format: .dateTime.month(.twoDigits).day().hour().minute())")
                        .fixedSize(horizontal: true, vertical: false)
                    Text(snapshot.generatedAt, format: .dateTime.month(.twoDigits).day().hour().minute())
                        .fixedSize(horizontal: true, vertical: false)
                    Text(snapshot.generatedAt, format: .dateTime.day().month(.twoDigits).year(.twoDigits))
                }
            }
        }
        .font(.caption2)
        .lineLimit(1)
        .accessibilityLabel(Text(
            "Updated \(snapshot.generatedAt, format: .dateTime.month(.twoDigits).day().hour().minute())"
        ))
    }
}

#if DEBUG
#Preview("Footer · Small · ES", as: .systemSmall) {
    ReadingWidgetLayoutPreview(locale: Locale(identifier: "es"), textSize: .large)
} timeline: {
    ReadingWidgetPreview.compactUnknownProgress
    ReadingWidgetPreview.content
}
#endif
