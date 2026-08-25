//
//  MangaRowView.swift
//  MangaLibrary
//

import SwiftUI

struct MangaRowView: View {
    let manga: Manga

    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    var body: some View {
        Group {
            if dynamicTypeSize.isAccessibilitySize {
                VStack(alignment: .leading, spacing: 12) {
                    MangaCoverView(url: manga.coverURL)
                    metadata
                }
            } else {
                HStack(alignment: .top, spacing: 12) {
                    MangaCoverView(url: manga.coverURL)
                    metadata
                }
            }
        }
        .accessibilityElement(children: .combine)
    }

    private var metadata: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(manga.title)
                .font(.headline)
                .foregroundStyle(.primary)

            if let titleEnglish = manga.titleEnglish,
               titleEnglish != manga.title {
                Text(titleEnglish)
                    .font(.subheadline)
            }

            Group {
                if dynamicTypeSize.isAccessibilitySize {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Score")
                        formattedScore
                    }
                } else {
                    HStack(spacing: 4) {
                        Text("Score")
                        formattedScore
                    }
                }
            }
            .font(.subheadline)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var formattedScore: some View {
        Text(manga.score, format: .number.precision(.fractionLength(1...2)))
    }
}

#Preview("Manga row") {
    MangaRowView(manga: CatalogPreviewSupport.mangas[0])
        .padding()
}
