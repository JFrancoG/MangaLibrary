//
//  CatalogDTO.swift
//  MangaLibrary
//

import Foundation

struct CatalogPageDTO: Decodable {
    private let items: [MangaDTO]
    private let metadata: PageMetadataDTO

    func catalogPage() throws -> CatalogPage {
        var identities: Set<Manga.ID> = []
        var mangas: [Manga] = []
        mangas.reserveCapacity(items.count)

        for item in items {
            let manga = item.manga()
            guard identities.insert(manga.id).inserted else {
                throw CatalogAPIClientError.duplicateMangaID(manga.id)
            }
            mangas.append(manga)
        }

        return CatalogPage(
            items: mangas,
            metadata: .init(
                page: metadata.page,
                per: metadata.per,
                total: metadata.total
            )
        )
    }
}

private struct PageMetadataDTO: Decodable {
    let page: Int64
    let per: Int64
    let total: Int64
}

private struct MangaDTO: Decodable {
    // Decode only values the product currently presents. Unknown remote fields
    // can then evolve without becoming false contract drift in this feature.
    let id: Int64
    let mainPicture: String?
    let score: Double
    let sypnosis: String?
    let title: String
    let titleEnglish: String?
    let titleJapanese: String?

    func manga() -> Manga {
        Manga(
            id: id,
            title: title,
            titleEnglish: titleEnglish,
            titleJapanese: titleJapanese,
            synopsis: sypnosis,
            score: score,
            coverURL: validatedCoverURL()
        )
    }

    private func validatedCoverURL() -> URL? {
        guard let mainPicture else {
            return nil
        }
        guard
            let components = URLComponents(string: mainPicture),
            let scheme = components.scheme?.lowercased(),
            ["http", "https"].contains(scheme),
            let host = components.host,
            !host.isEmpty,
            components.user == nil,
            components.password == nil,
            let url = components.url
        else { return nil }

        return url
    }
}
