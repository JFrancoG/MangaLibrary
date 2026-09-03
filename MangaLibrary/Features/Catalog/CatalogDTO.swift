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
            guard item.reportedTotalVolumes.map(CollectionVolumePolicy.contains) ?? true else {
                throw CatalogAPIClientError.contractDrift
            }
            let manga = item.manga()
            guard identities.insert(manga.id).inserted else {
                throw CatalogAPIClientError.duplicateMangaID(manga.id)
            }
            mangas.append(manga)
        }

        return CatalogPage(
            items: mangas,
            metadata: .init(page: metadata.page, per: metadata.per, total: metadata.total)
        )
    }
}

private struct PageMetadataDTO: Decodable {
    let page: Int64
    let per: Int64
    let total: Int64
}
