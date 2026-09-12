import CoreGraphics
import SwiftUI
import WidgetKit

struct CollectionWidgetRowView: View {
    let item: CollectionWidgetSnapshot.Item
    let cover: CGImage?
    @ScaledMetric(relativeTo: .headline) private var coverHeight = 76.0
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @Environment(\.locale) private var locale

    var body: some View {
        ViewThatFits(in: .vertical) {
            if !dynamicTypeSize.isAccessibilitySize {
                HStack(alignment: .center, spacing: 10) {
                    Group {
                        if let cover {
                            Image(decorative: cover, scale: 1)
                                .resizable()
                                .scaledToFit()
                        } else {
                            Image(systemName: "books.vertical")
                                .font(.title3)
                                .foregroundStyle(.brandPrimaryInk)
                                .frame(maxWidth: .infinity, maxHeight: .infinity)
                                .background(.surfaceStrong, in: .rect(cornerRadius: 3))
                        }
                    }
                    .frame(width: coverHeight * 2 / 3, height: coverHeight)
                    .accessibilityHidden(true)
                    VStack(alignment: .leading, spacing: 3) {
                        title
                            .font(.headline)
                            .lineLimit(2)
                            .minimumScaleFactor(0.85)
                        ownership
                            .font(.footnote)
                        completion
                            .font(.caption.weight(.semibold))
                    }
                    .fixedSize(horizontal: false, vertical: true)
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
            VStack(alignment: .leading, spacing: dynamicTypeSize.isAccessibilitySize ? 0 : 3) {
                title
                    .font(.caption.weight(.semibold))
                    .lineLimit(1)
                HStack(alignment: .firstTextBaseline, spacing: 8) {
                    compactOwnership
                    completion
                }
                .font(.caption2)
            }
            .fixedSize(horizontal: false, vertical: true)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .accessibilityElement(children: .combine)
    }

    private var title: some View {
        Group {
            if let title = item.title {
                Text(title)
            } else {
                Text("Manga #\(item.mangaID)")
            }
        }
        .foregroundStyle(.textPrimary)
    }

    private var ownership: some View {
        Group {
            if let total = item.totalVolumes {
                Text("\(item.ownedVolumeCount)/\(total) volumes owned")
                    .accessibilityLabel(Text("\(item.ownedVolumeCount) of \(total) volumes owned"))
            } else {
                Text("\(item.ownedVolumeCount) volumes owned")
            }
        }
        .foregroundStyle(.textSecondary)
    }

    private var compactOwnership: some View {
        Group {
            if let total = item.totalVolumes {
                let ownedCount = item.ownedVolumeCount.formatted(.number.locale(locale))
                let totalCount = total.formatted(.number.locale(locale))
                Text(verbatim: "\(ownedCount)/\(totalCount)")
                    .accessibilityLabel(Text("\(item.ownedVolumeCount) of \(total) volumes owned"))
            } else {
                Text("\(item.ownedVolumeCount) volumes")
                    .accessibilityLabel(Text("\(item.ownedVolumeCount) volumes owned"))
            }
        }
        .foregroundStyle(.textSecondary)
    }

    private var completion: some View {
        Text(completionTitle)
            .foregroundStyle(.textSecondary)
            .accessibilityLabel(Text(completionLabel))
    }

    private var completionTitle: LocalizedStringResource { item.isComplete ? "Complete" : "Incomplete" }

    private var completionLabel: LocalizedStringResource {
        item.isComplete ? "Collection complete" : "Collection incomplete"
    }
}

#if DEBUG
#Preview("Completed collection", as: .systemMedium) {
    ReadingWidgetComponentPreview(component: .collectionWidgetRow, locale: Locale(identifier: "es"))
} timeline: {
    CollectionWidgetPreview.completed
}
#endif
