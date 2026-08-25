//
//  MangaDetailView.swift
//  MangaLibrary
//

import SwiftUI

struct MangaDetailView: View {
    let manga: Manga

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                MangaCoverView(url: manga.coverURL)

                Text(manga.title)
                    .font(.largeTitle)
                    .bold()
                    .accessibilityHeading(.h1)

                if let titleEnglish = manga.titleEnglish,
                   titleEnglish != manga.title {
                    Text(titleEnglish)
                        .font(.title3)
                }

                if let titleJapanese = manga.titleJapanese {
                    Text(titleJapanese)
                        .font(.title3)
                }

                LabeledContent("Score") {
                    Text(
                        manga.score,
                        format: .number.precision(.fractionLength(1...2))
                    )
                    .foregroundStyle(.primary)
                }

                if let synopsis = manga.synopsis {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Synopsis")
                            .font(.headline)
                            .accessibilityHeading(.h2)
                        Text(synopsis)
                            .font(.body)
                    }
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding()
        }
        .navigationTitle(manga.title)
        .navigationBarTitleDisplayMode(.inline)
        .accessibilityIdentifier("manga.detail.\(manga.id)")
    }
}

#Preview("Manga detail") {
    NavigationStack {
        MangaDetailView(manga: CatalogPreviewSupport.mangas[0])
    }
}
