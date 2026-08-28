//
//  MangaGridItemView.swift
//  MangaLibrary
//

import SwiftUI

struct MangaGridItemView: View {
    let manga: Manga

    var body: some View {
        VStack(alignment: .center, spacing: 10) {
            MangaCoverView(url: manga.coverURL, presentation: .grid)
                .frame(maxWidth: .infinity)

            Text(manga.title)
                .font(.headline)
                .foregroundStyle(.primary)
                .multilineTextAlignment(.center)
                .lineLimit(2, reservesSpace: true)
                .truncationMode(.tail)
                .frame(maxWidth: .infinity, alignment: .center)
        }
        .frame(maxWidth: .infinity, alignment: .center)
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
