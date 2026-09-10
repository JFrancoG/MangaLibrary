import SwiftUI

struct WatchReadingRowView: View {
    let item: ReadingSnapshot.Item

    var body: some View {
        HStack(alignment: .top, spacing: 8) {
            Image(systemName: "book.closed")
                .font(.headline)
                .foregroundStyle(.brandPrimaryInk)
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 6) {
                Group {
                    if let title = item.title {
                        Text(title)
                    } else {
                        Text("Manga #\(item.mangaID)")
                    }
                }
                .font(.headline)
                .foregroundStyle(.textPrimary)
                Group {
                    if let total = item.totalVolumes {
                        Text("Volume \(item.readingVolume) of \(total)")
                    } else {
                        Text("Volume \(item.readingVolume) · Total unknown")
                    }
                }
                .font(.footnote)
                .foregroundStyle(.textSecondary)
            }
            .fixedSize(horizontal: false, vertical: true)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(.vertical, 4)
        .accessibilityElement(children: .combine)
    }
}

#Preview("Unknown total · ES") {
    List {
        WatchReadingRowView(item: WatchReadingPreview.content.items[1])
            .listRowBackground(Color.surface)
    }
    .environment(\.locale, Locale(identifier: "es"))
}

#Preview("Final volume · EN") {
    List {
        WatchReadingRowView(item: WatchReadingPreview.content.items[2])
            .listRowBackground(Color.surface)
    }
    .environment(\.locale, Locale(identifier: "en"))
}
