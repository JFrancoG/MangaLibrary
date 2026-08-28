//
//  CatalogPreviewSupport.swift
//  MangaLibrary
//

import Foundation

enum CatalogPreviewSupport {
    private static let authorID = UUID(
        uuid: (17, 17, 17, 17, 17, 17, 17, 17, 17, 17, 17, 17, 17, 17, 17, 17)
    )
    private static let storyAuthorID = UUID(
        uuid: (18, 18, 18, 18, 18, 18, 18, 18, 18, 18, 18, 18, 18, 18, 18, 18)
    )
    private static let artAuthorID = UUID(
        uuid: (19, 19, 19, 19, 19, 19, 19, 19, 19, 19, 19, 19, 19, 19, 19, 19)
    )
    private static let demographicID = UUID(
        uuid: (34, 34, 34, 34, 34, 34, 34, 34, 34, 34, 34, 34, 34, 34, 34, 34)
    )
    private static let genreID = UUID(
        uuid: (51, 51, 51, 51, 51, 51, 51, 51, 51, 51, 51, 51, 51, 51, 51, 51)
    )
    private static let themeID = UUID(
        uuid: (68, 68, 68, 68, 68, 68, 68, 68, 68, 68, 68, 68, 68, 68, 68, 68)
    )

    static let filterOptions = CatalogFilterOptions(
        demographics: ["Josei", "Seinen", "Shounen"],
        genres: ["Action", "Adventure", "Drama", "Mystery"],
        themes: ["Adult Cast", "Military", "Psychological", "Space"]
    )

    static let mangas = [
        Manga(
            id: 1,
            title: "Fullmetal Alchemist",
            titleEnglish: "Fullmetal Alchemist",
            titleJapanese: "鋼の錬金術師",
            synopsis: "Two brothers search for the Philosopher's Stone after an alchemical ritual changes their lives.",
            score: 9.12,
            status: .finished,
            authors: [
                Manga.Author(
                    id: authorID,
                    firstName: "Hiromu",
                    lastName: "Arakawa",
                    role: .storyAndArt
                )
            ],
            demographics: [
                Manga.Classification(
                    id: demographicID,
                    name: "Shounen"
                )
            ],
            genres: [
                Manga.Classification(
                    id: genreID,
                    name: "Adventure"
                )
            ],
            themes: [
                Manga.Classification(
                    id: themeID,
                    name: "Military"
                )
            ],
            coverURL: nil
        ),
        Manga(
            id: 2,
            title: "A deliberately long manga title that exercises multiline layout",
            titleEnglish: nil,
            titleJapanese: nil,
            synopsis: nil,
            score: 8.4,
            status: .publishing,
            authors: [
                Manga.Author(
                    id: storyAuthorID,
                    firstName: "Aiko",
                    lastName: "Tanaka",
                    role: .story
                ),
                Manga.Author(
                    id: artAuthorID,
                    firstName: "Luis",
                    lastName: "García",
                    role: .art
                )
            ],
            demographics: [],
            genres: [],
            themes: [],
            coverURL: nil
        ),
        Manga(
            id: 3,
            title: "Monster",
            titleEnglish: nil,
            titleJapanese: "MONSTER",
            synopsis: "A doctor confronts the consequences of saving one life.",
            score: 9.15,
            status: .finished,
            authors: [],
            demographics: [],
            genres: [],
            themes: [],
            coverURL: nil
        ),
        Manga(
            id: 4,
            title: "Nausicaä of the Valley of the Wind",
            titleEnglish: "Nausicaä of the Valley of the Wind",
            titleJapanese: "風の谷のナウシカ",
            synopsis: nil,
            score: 8.85,
            status: .finished,
            authors: [],
            demographics: [],
            genres: [],
            themes: [],
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

    static let filterOptionsLoader: CatalogModel.FilterOptionsLoader = {
        filterOptions
    }

    @MainActor
    static func model(
        state: CatalogModel.State,
        query: CatalogQuery = .catalog,
        filterOptionsState: CatalogModel.FilterOptionsState = .idle
    ) -> CatalogModel {
        CatalogModel(
            initialState: state,
            initialQuery: query,
            initialFilterOptionsState: filterOptionsState,
            loadFilterOptions: filterOptionsLoader,
            loadPage: pageLoader
        )
    }
}
