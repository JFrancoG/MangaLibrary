//
//  MangaGridItemView.swift
//  MangaLibrary
//

import SwiftUI

struct MangaGridItemView: View {
    let manga: Manga

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            MangaCoverView(url: manga.coverURL, presentation: .grid)
                .frame(maxWidth: .infinity)

            Text(manga.title)
                .font(.headline)
                .foregroundStyle(.primary)

            if let titleEnglish = manga.titleEnglish,
               titleEnglish != manga.title {
                Text(titleEnglish)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            LabeledContent("Score") {
                Text(
                    manga.score,
                    format: .number.precision(.fractionLength(1...2))
                )
                .foregroundStyle(.primary)
            }
            .font(.subheadline)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(12)
        .background(.background)
        .overlay {
            RoundedRectangle(cornerRadius: 12)
                .stroke(.quaternary, lineWidth: 1)
        }
        .compositingGroup()
        .clipShape(.rect(cornerRadius: 12))
        .contentShape(.rect)
        .accessibilityElement(children: .combine)
    }
}

#Preview("Manga grid item") {
    MangaGridItemView(manga: CatalogPreviewSupport.mangas[0])
        .frame(width: 220)
        .padding()
}
