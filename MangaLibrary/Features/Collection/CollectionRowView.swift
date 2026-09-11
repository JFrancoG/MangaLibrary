//
//  CollectionRowView.swift
//  MangaLibrary
//

import SwiftData
import SwiftUI

struct CollectionRowView: View {
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    let entry: CollectionEntry

    var body: some View {
        Group {
            if dynamicTypeSize.isAccessibilitySize {
                VStack(alignment: .leading, spacing: 12) {
                    MangaCoverView(url: entry.mangaSnapshot?.coverURL, presentation: .row)
                    metadata

                    if entry.isComplete {
                        completionIndicator
                    }
                }
            } else {
                HStack(spacing: 12) {
                    MangaCoverView(url: entry.mangaSnapshot?.coverURL, presentation: .row)
                    metadata
                    Spacer(minLength: 8)

                    if entry.isComplete {
                        completionIndicator
                    }
                }
            }
        }
        .accessibilityElement(children: .combine)
        .accessibilityIdentifier("collection.row.\(entry.mangaID)")
    }

    private var metadata: some View {
        VStack(alignment: .leading, spacing: 4) {
            if let title = entry.mangaSnapshot?.title {
                Text(title)
                    .font(.headline)
                    .foregroundStyle(.textPrimary)
            } else {
                Text("Manga #\(entry.mangaID)")
                    .font(.headline)
                    .foregroundStyle(.textPrimary)
                Text("Offline details unavailable")
                    .font(.subheadline)
                    .foregroundStyle(.textSecondary)
            }

            Text(ownedVolumesDescription)
                .font(.subheadline)
                .foregroundStyle(.textSecondary)

            if let readingVolume = entry.readingVolume {
                Text("Reading volume \(readingVolume)")
                    .font(.subheadline)
                    .foregroundStyle(.textSecondary)
            }
        }
    }

    private var completionIndicator: some View {
        Image(systemName: "checkmark.seal.fill")
            .foregroundStyle(.brandPrimaryInk)
            .accessibilityLabel("Complete collection")
    }

    private var ownedVolumesDescription: LocalizedStringResource {
        if entry.ownedVolumes.isEmpty {
            "No owned volumes"
        } else {
            "Owned volumes: \(entry.ownedVolumes.count)"
        }
    }
}

#Preview("Collection row", traits: .modifier(CollectionPreviewModifier<CollectionPreviewScenarios.Row>())) {
    @Previewable @Environment(\.modelContext) var modelContext
    CollectionPreviewSupport.row(container: modelContext.container)
}
