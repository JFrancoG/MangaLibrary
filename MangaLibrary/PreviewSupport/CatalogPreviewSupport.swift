//
//  CatalogPreviewSupport.swift
//  MangaLibrary
//

enum CatalogPreviewSupport {
    static let mangas = [
        Manga(
            id: 1,
            title: "Fullmetal Alchemist",
            titleEnglish: "Fullmetal Alchemist",
            titleJapanese: "鋼の錬金術師",
            synopsis: "Two brothers search for the Philosopher's Stone after an alchemical ritual changes their lives.",
            score: 9.12,
            coverURL: nil
        ),
        Manga(
            id: 2,
            title: "A deliberately long manga title that exercises multiline layout",
            titleEnglish: nil,
            titleJapanese: nil,
            synopsis: nil,
            score: 8.4,
            coverURL: nil
        ),
        Manga(
            id: 3,
            title: "Monster",
            titleEnglish: nil,
            titleJapanese: "MONSTER",
            synopsis: "A doctor confronts the consequences of saving one life.",
            score: 9.15,
            coverURL: nil
        ),
        Manga(
            id: 4,
            title: "Nausicaä of the Valley of the Wind",
            titleEnglish: "Nausicaä of the Valley of the Wind",
            titleJapanese: "風の谷のナウシカ",
            synopsis: nil,
            score: 8.85,
            coverURL: nil
        )
    ]

    /// Deterministic domain data for previews and the single Debug UI smoke.
    ///
    /// This loader deliberately bypasses URLSession, DTOs and JSON. Their
    /// behavior is covered at the transport and typed-client boundaries.
    static let pageLoader: CatalogModel.PageLoader = { request in
        let items = request.page == 1 ? mangas : []

        return CatalogPage(
            items: items,
            metadata: .init(
                page: request.page,
                per: request.per,
                total: Int64(mangas.count)
            )
        )
    }

    @MainActor
    static func model(state: CatalogModel.State) -> CatalogModel {
        CatalogModel(initialState: state, loadPage: pageLoader)
    }
}
