import SwiftUI

struct WatchReadingView: View {
    let snapshot: ReadingSnapshot?
    var isTemporarilyUnavailable = false

    var body: some View {
        NavigationStack {
            List {
                if let snapshot {
                    if isTemporarilyUnavailable && (snapshot.state == .content || snapshot.state == .empty) {
                        Text("Couldn't refresh your readings. Open Manga Library on your iPhone.")
                            .font(.footnote)
                            .foregroundStyle(.textSecondary)
                            .fixedSize(horizontal: false, vertical: true)
                            .listRowBackground(Color.surface)
                    }
                    switch snapshot.state {
                    case .content:
                        ForEach(snapshot.items, id: \.mangaID) { item in
                            WatchReadingRowView(item: item)
                                .listRowBackground(Color.surface)
                        }
                    case .empty:
                        WatchReadingStateView(state: .empty)
                            .listRowBackground(Color.surface)
                    case .redacted:
                        WatchReadingStateView(state: .redacted)
                            .listRowBackground(Color.surface)
                    case .unavailable:
                        WatchReadingStateView(state: .unavailable)
                            .listRowBackground(Color.surface)
                    }
                    if snapshot.state == .content || snapshot.state == .empty {
                        VStack(alignment: .leading, spacing: 8) {
                            if let total = snapshot.totalEligibleCount, total > Int64(snapshot.items.count) {
                                Text("\(total - Int64(snapshot.items.count)) more on iPhone")
                            }
                            Text(
                                "Updated \(snapshot.generatedAt, format: .dateTime.year().month().day().hour().minute())"
                            )
                        }
                        .font(.footnote)
                        .foregroundStyle(.textSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                        .accessibilityElement(children: .combine)
                        .listRowBackground(Color.surface)
                    }
                } else {
                    WatchReadingStateView(state: .unavailable)
                        .listRowBackground(Color.surface)
                }
            }
            .navigationTitle("Reading")
            .tint(.brandPrimaryInk)
        }
    }
}

#Preview("Reading · ES") {
    WatchReadingView(snapshot: WatchReadingPreview.content)
        .environment(\.locale, Locale(identifier: "es"))
}

#Preview("Long titles · EN · XXX Large") {
    WatchReadingView(snapshot: WatchReadingPreview.longTitles)
        .environment(\.locale, Locale(identifier: "en"))
        .environment(\.dynamicTypeSize, .xxxLarge)
}

#Preview("Reading · ES · AX 5") {
    WatchReadingView(snapshot: WatchReadingPreview.content)
        .environment(\.locale, Locale(identifier: "es"))
        .environment(\.dynamicTypeSize, .accessibility5)
}

#Preview("Saved readings · EN") {
    WatchReadingView(snapshot: WatchReadingPreview.content, isTemporarilyUnavailable: true)
        .environment(\.locale, Locale(identifier: "en"))
}

#Preview("Empty · ES") {
    WatchReadingView(snapshot: WatchReadingPreview.empty)
        .environment(\.locale, Locale(identifier: "es"))
}

#Preview("Redacted · ES") {
    WatchReadingView(snapshot: WatchReadingPreview.redacted)
        .environment(\.locale, Locale(identifier: "es"))
}

#Preview("Unavailable · EN") {
    WatchReadingView(snapshot: nil)
        .environment(\.locale, Locale(identifier: "en"))
}
