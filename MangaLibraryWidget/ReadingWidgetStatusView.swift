import SwiftUI
import WidgetKit

struct ReadingWidgetStatusView: View {
    enum State {
        case empty
        case redacted
        case unavailable
    }

    enum Content {
        case reading
        case collection
    }

    let state: State
    var content = Content.reading
    var statusIllustration: CGImage?
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @Environment(\.widgetFamily) private var family
    @ScaledMetric(relativeTo: .title2) private var largeIllustrationSize = 140.0
    @ScaledMetric(relativeTo: .headline) private var mediumIllustrationSize = 72.0
    @ScaledMetric(relativeTo: .headline) private var smallIllustrationSize = 32.0

    var body: some View {
        ViewThatFits(in: .vertical) {
            if !dynamicTypeSize.isAccessibilitySize {
                illustratedContent
            }
            textBlock(titleFont: titleFont, messageFont: messageFont)
            textBlock(titleFont: .subheadline.weight(.semibold), messageFont: .caption)
            textBlock(titleFont: .caption.weight(.semibold), messageFont: .caption2)
            textBlock(titleFont: .caption2.weight(.semibold), messageFont: .caption2)
            textBlock(titleFont: .caption2.weight(.semibold), messageFont: .caption2, usesCompactMessage: true)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .multilineTextAlignment(usesLeadingText ? .leading : .center)
        .accessibilityElement(children: .combine)
    }

    @ViewBuilder
    private var illustratedContent: some View {
        if family == .systemMedium {
            HStack(alignment: .center, spacing: 12) {
                illustration
                textBlock(titleFont: titleFont, messageFont: messageFont)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
        } else {
            VStack(spacing: family == .systemLarge ? 16 : 8) {
                illustration
                textBlock(titleFont: titleFont, messageFont: messageFont)
            }
        }
    }

    @ViewBuilder
    private var illustration: some View {
        if let image = statusIllustration {
            Image(decorative: image, scale: 1)
                .resizable()
                .scaledToFit()
                .frame(width: illustrationSize, height: illustrationSize)
                .accessibilityHidden(true)
        }
    }

    private func textBlock(titleFont: Font, messageFont: Font, usesCompactMessage: Bool = false) -> some View {
        VStack(alignment: usesLeadingText ? .leading : .center, spacing: dynamicTypeSize.isAccessibilitySize ? 4 : 8) {
            Text(title)
                .font(titleFont)
                .foregroundStyle(.textPrimary)
                .fixedSize(horizontal: false, vertical: true)
            Text(usesCompactMessage ? compactMessage : message)
                .font(messageFont)
                .foregroundStyle(.textSecondary)
                .fixedSize(horizontal: false, vertical: true)
                .accessibilityLabel(Text(message))
        }
    }

    private var illustrationSize: Double {
        switch family {
        case .systemLarge: largeIllustrationSize
        case .systemMedium: mediumIllustrationSize
        default: smallIllustrationSize
        }
    }

    private var usesLeadingText: Bool { family == .systemMedium }

    private var titleFont: Font {
        family == .systemLarge ? .title2.weight(.semibold) : .headline
    }

    private var messageFont: Font {
        family == .systemLarge ? .body : .caption
    }

    private var title: LocalizedStringResource {
        switch (content, state) {
        case (.reading, .empty): "What are you reading?"
        case (.collection, .empty): "No manga in your collection"
        case (_, .redacted): "Your manga, right here"
        case (_, .unavailable): "Let's refresh"
        }
    }

    private var message: LocalizedStringResource {
        switch (content, state) {
        case (.reading, .empty): "Set your current volume in Manga Library."
        case (.collection, .empty): "Add manga to your collection in Manga Library."
        case (_, .redacted): "Sign in to Manga Library."
        case (_, .unavailable): "Open Manga Library and we'll refresh your manga."
        }
    }

    private var compactMessage: LocalizedStringResource {
        state == .redacted ? "Sign in." : "Open Manga Library."
    }
}

#if DEBUG
#Preview("Signed-out collection", as: .systemMedium) {
    ReadingWidgetComponentPreview(component: .readingWidgetStatus)
} timeline: {
    CollectionWidgetPreview.redacted
}
#endif
