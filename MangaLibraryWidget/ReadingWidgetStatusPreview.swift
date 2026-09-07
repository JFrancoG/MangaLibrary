import SwiftUI
import WidgetKit

#if DEBUG
#Preview("Status · Small · EN · Standard", as: .systemSmall) {
    ReadingWidgetLayoutPreview(locale: Locale(identifier: "en"), textSize: .large)
} timeline: {
    ReadingWidgetPreview.empty.preparingStatusIllustration(for: .systemSmall)
    ReadingWidgetPreview.redacted.preparingStatusIllustration(for: .systemSmall)
    ReadingWidgetPreview.unavailable
}

#Preview("Status · Small · ES · Standard", as: .systemSmall) {
    ReadingWidgetLayoutPreview(locale: Locale(identifier: "es"), textSize: .large)
} timeline: {
    ReadingWidgetPreview.empty.preparingStatusIllustration(for: .systemSmall)
    ReadingWidgetPreview.redacted.preparingStatusIllustration(for: .systemSmall)
    ReadingWidgetPreview.unavailable
}

#Preview("Status · Small · EN · AX 5", as: .systemSmall) {
    ReadingWidgetLayoutPreview(locale: Locale(identifier: "en"), textSize: .accessibility5)
} timeline: {
    ReadingWidgetPreview.empty.preparingStatusIllustration(for: .systemSmall)
    ReadingWidgetPreview.redacted.preparingStatusIllustration(for: .systemSmall)
    ReadingWidgetPreview.unavailable
}

#Preview("Status · Small · ES · AX 5", as: .systemSmall) {
    ReadingWidgetLayoutPreview(locale: Locale(identifier: "es"), textSize: .accessibility5)
} timeline: {
    ReadingWidgetPreview.empty.preparingStatusIllustration(for: .systemSmall)
    ReadingWidgetPreview.redacted.preparingStatusIllustration(for: .systemSmall)
    ReadingWidgetPreview.unavailable
}

#Preview("Status · Medium · EN · Standard", as: .systemMedium) {
    ReadingWidgetLayoutPreview(locale: Locale(identifier: "en"), textSize: .large)
} timeline: {
    CollectionWidgetPreview.empty.preparingStatusIllustration(for: .systemMedium)
    CollectionWidgetPreview.redacted.preparingStatusIllustration(for: .systemMedium)
    CollectionWidgetPreview.unavailable
}

#Preview("Status · Medium · ES · Standard", as: .systemMedium) {
    ReadingWidgetLayoutPreview(locale: Locale(identifier: "es"), textSize: .large)
} timeline: {
    CollectionWidgetPreview.empty.preparingStatusIllustration(for: .systemMedium)
    CollectionWidgetPreview.redacted.preparingStatusIllustration(for: .systemMedium)
    CollectionWidgetPreview.unavailable
}

#Preview("Status · Medium · EN · AX 5", as: .systemMedium) {
    ReadingWidgetLayoutPreview(locale: Locale(identifier: "en"), textSize: .accessibility5)
} timeline: {
    CollectionWidgetPreview.empty.preparingStatusIllustration(for: .systemMedium)
    CollectionWidgetPreview.redacted.preparingStatusIllustration(for: .systemMedium)
    CollectionWidgetPreview.unavailable
}

#Preview("Status · Medium · ES · AX 5", as: .systemMedium) {
    ReadingWidgetLayoutPreview(locale: Locale(identifier: "es"), textSize: .accessibility5)
} timeline: {
    CollectionWidgetPreview.empty.preparingStatusIllustration(for: .systemMedium)
    CollectionWidgetPreview.redacted.preparingStatusIllustration(for: .systemMedium)
    CollectionWidgetPreview.unavailable
}

#Preview("Status · Large · EN · Standard", as: .systemLarge) {
    ReadingWidgetLayoutPreview(locale: Locale(identifier: "en"), textSize: .large)
} timeline: {
    ReadingWidgetPreview.empty.preparingStatusIllustration(for: .systemLarge)
    ReadingWidgetPreview.redacted.preparingStatusIllustration(for: .systemLarge)
    ReadingWidgetPreview.unavailable
}

#Preview("Status · Large · ES · Standard", as: .systemLarge) {
    ReadingWidgetLayoutPreview(locale: Locale(identifier: "es"), textSize: .large)
} timeline: {
    ReadingWidgetPreview.empty.preparingStatusIllustration(for: .systemLarge)
    ReadingWidgetPreview.redacted.preparingStatusIllustration(for: .systemLarge)
    ReadingWidgetPreview.unavailable
}

#Preview("Status · Large · EN · AX 5", as: .systemLarge) {
    ReadingWidgetLayoutPreview(locale: Locale(identifier: "en"), textSize: .accessibility5)
} timeline: {
    ReadingWidgetPreview.empty.preparingStatusIllustration(for: .systemLarge)
    ReadingWidgetPreview.redacted.preparingStatusIllustration(for: .systemLarge)
    ReadingWidgetPreview.unavailable
}

#Preview("Status · Large · ES · AX 5", as: .systemLarge) {
    ReadingWidgetLayoutPreview(locale: Locale(identifier: "es"), textSize: .accessibility5)
} timeline: {
    ReadingWidgetPreview.empty.preparingStatusIllustration(for: .systemLarge)
    ReadingWidgetPreview.redacted.preparingStatusIllustration(for: .systemLarge)
    ReadingWidgetPreview.unavailable
}

#Preview("Status · Small · ES · XXX Large", as: .systemSmall) {
    ReadingWidgetLayoutPreview(locale: Locale(identifier: "es"), textSize: .xxxLarge)
} timeline: {
    ReadingWidgetPreview.empty.preparingStatusIllustration(for: .systemSmall)
    ReadingWidgetPreview.redacted.preparingStatusIllustration(for: .systemSmall)
    ReadingWidgetPreview.unavailable
}

#Preview("Status · Medium · ES · XXX Large", as: .systemMedium) {
    ReadingWidgetLayoutPreview(locale: Locale(identifier: "es"), textSize: .xxxLarge)
} timeline: {
    CollectionWidgetPreview.empty.preparingStatusIllustration(for: .systemMedium)
    CollectionWidgetPreview.redacted.preparingStatusIllustration(for: .systemMedium)
    CollectionWidgetPreview.unavailable
}

#Preview("Status · Large · ES · XXX Large", as: .systemLarge) {
    ReadingWidgetLayoutPreview(locale: Locale(identifier: "es"), textSize: .xxxLarge)
} timeline: {
    ReadingWidgetPreview.empty.preparingStatusIllustration(for: .systemLarge)
    ReadingWidgetPreview.redacted.preparingStatusIllustration(for: .systemLarge)
    ReadingWidgetPreview.unavailable
}

#endif
