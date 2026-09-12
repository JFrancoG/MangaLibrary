//
//  MangaRowView.swift
//  MangaLibrary
//

import Foundation
import SwiftUI

struct MangaRowView: View {
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @Environment(\.locale) private var locale

    let manga: Manga

    var body: some View {
        Group {
            if dynamicTypeSize.isAccessibilitySize {
                VStack(alignment: .leading, spacing: 12) {
                    MangaCoverView(url: manga.coverURL)
                    metadata
                }
            } else {
                HStack(alignment: .center, spacing: 12) {
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

            if manga.authors.isEmpty == false {
                Text(formattedAuthors)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var formattedAuthors: String {
        manga.authors
            .map { author in
                author.nameComponents.formatted(.name(style: .medium).locale(locale))
            }
            .formatted(.list(type: .and).locale(locale))
    }
}

#Preview("Manga row") {
    MangaRowView(manga: CatalogPreviewSupport.mangas[0])
        .padding()
}
