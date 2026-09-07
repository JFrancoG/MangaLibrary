import CoreGraphics
import SwiftUI

struct ReadingWidgetRowView: View {
    enum Style {
        case compact
        case prominent
        case singleReading
        case twoReadings
        case threeReadings
        case fourReadings
        case fiveReadings
        case sixReadings
    }

    let item: ReadingSnapshot.Item
    let cover: CGImage?
    var style = Style.compact
    var usesCompactProgress = false
    var usesLargerRows = false

    @ScaledMetric(relativeTo: .headline) private var prominentCoverHeight = 60.0
    @ScaledMetric(relativeTo: .caption) private var compactCoverHeight = 40.0
    @ScaledMetric(relativeTo: .title2) private var singleCoverHeight = 184.0
    @ScaledMetric(relativeTo: .title3) private var twoCoverHeight = 104.0
    @ScaledMetric(relativeTo: .headline) private var threeCoverHeight = 76.0
    @ScaledMetric(relativeTo: .subheadline) private var fourCoverHeight = 56.0
    @ScaledMetric(relativeTo: .caption) private var fiveCoverHeight = 48.0
    @ScaledMetric(relativeTo: .caption) private var sixCoverHeight = 44.0
    @ScaledMetric(relativeTo: .footnote) private var largerFiveCoverHeight = 56.0
    @ScaledMetric(relativeTo: .footnote) private var largerSixCoverHeight = 47.0
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    var body: some View {
        HStack(alignment: .center, spacing: 8) {
            if !dynamicTypeSize.isAccessibilitySize {
                Group {
                    if let cover {
                        Image(decorative: cover, scale: 1)
                            .resizable()
                            .scaledToFit()
                    } else {
                        Image(systemName: "book.closed")
                            .font(.caption)
                            .foregroundStyle(.brandPrimaryInk)
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                            .background(.surfaceStrong, in: .rect(cornerRadius: 3))
                    }
                }
                .frame(width: coverHeight * 2 / 3, height: coverHeight)
                .accessibilityHidden(true)
            }
            VStack(alignment: .leading, spacing: dynamicTypeSize.isAccessibilitySize ? 1 : 3) {
                Group {
                    if let title = item.title {
                        Text(title)
                    } else {
                        Text("Manga #\(item.mangaID)")
                    }
                }
                .font(titleFont)
                .foregroundStyle(.textPrimary)
                .lineLimit(dynamicTypeSize.isAccessibilitySize ? 1 : 2)
                .minimumScaleFactor(dynamicTypeSize.isAccessibilitySize ? 1 : 0.85)
                .fixedSize(horizontal: false, vertical: true)
                Group {
                    if usesCompactProgress && !dynamicTypeSize.isAccessibilitySize {
                        ViewThatFits(in: .horizontal) {
                            compactProgress
                                .font(progressFont)
                                .fixedSize()
                            compactProgress
                                .font(.caption2)
                                .fixedSize()
                            compactProgress
                                .font(.caption2)
                                .lineLimit(1)
                                .minimumScaleFactor(0.85)
                        }
                    } else if usesCompactProgress {
                        compactProgress
                    } else {
                        fullProgress
                    }
                }
                .font(progressFont)
                .foregroundStyle(.textSecondary)
                .fixedSize(horizontal: false, vertical: true)
                .accessibilityLabel(fullProgress)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .accessibilityElement(children: .combine)
    }

    private var compactProgress: Text {
        if let total = item.totalVolumes {
            Text("Volume \(item.readingVolume)/\(total)")
        } else {
            Text("Volume \(item.readingVolume)")
        }
    }

    private var fullProgress: Text {
        if let total = item.totalVolumes {
            Text("Volume \(item.readingVolume) of \(total)")
        } else {
            Text("Volume \(item.readingVolume) · Total unknown")
        }
    }

    private var coverHeight: Double {
        switch style {
        case .compact: compactCoverHeight
        case .prominent: prominentCoverHeight
        case .singleReading: singleCoverHeight
        case .twoReadings: twoCoverHeight
        case .threeReadings: threeCoverHeight
        case .fourReadings: fourCoverHeight
        case .fiveReadings: usesLargerRows ? largerFiveCoverHeight : fiveCoverHeight
        case .sixReadings: usesLargerRows ? largerSixCoverHeight : sixCoverHeight
        }
    }

    private var titleFont: Font {
        guard !dynamicTypeSize.isAccessibilitySize else { return .caption.weight(.semibold) }
        return switch style {
        case .compact: .caption.weight(.semibold)
        case .fiveReadings, .sixReadings: (usesLargerRows ? Font.footnote : .caption).weight(.semibold)
        case .prominent, .threeReadings: .headline
        case .singleReading: .title2.weight(.semibold)
        case .twoReadings: .title3.weight(.semibold)
        case .fourReadings: .subheadline.weight(.semibold)
        }
    }

    private var progressFont: Font {
        guard !dynamicTypeSize.isAccessibilitySize else { return .caption2 }
        return switch style {
        case .compact: .caption2
        case .fiveReadings, .sixReadings: usesLargerRows ? .caption : .caption2
        case .prominent, .fourReadings: .footnote
        case .singleReading, .twoReadings: .body
        case .threeReadings: .subheadline
        }
    }
}
