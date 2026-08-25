//
//  CatalogPage.swift
//  MangaLibrary
//

struct CatalogPage: Equatable {
    struct Metadata: Equatable {
        let page: Int64
        let per: Int64
        let total: Int64
    }

    let items: [Manga]
    let metadata: Metadata
}
