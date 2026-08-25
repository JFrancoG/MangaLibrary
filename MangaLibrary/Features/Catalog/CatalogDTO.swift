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
    let authors: [AuthorDTO]
    let background: String?
    let chapters: Int64?
    let demographics: [DemographicDTO]
    let endDate: String?
    let genres: [GenreDTO]
    let id: Int64
    let mainPicture: String?
    let score: Double
    let startDate: String?
    let status: MangaStatusDTO
    let sypnosis: String?
    let themes: [ThemeDTO]
    let title: String
    let titleEnglish: String?
    let titleJapanese: String?
    let url: String?
    let volumes: Int64?

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

private struct AuthorDTO: Decodable {
    let firstName: String
    let id: UUID
    let lastName: String
    let role: AuthorRoleDTO
}

private enum AuthorRoleDTO: String, Decodable {
    case art = "Art"
    case storyAndArt = "Story & Art"
    case story = "Story"
    case none = "None"
}

private struct DemographicDTO: Decodable {
    let demographic: String
    let id: UUID
}

private struct GenreDTO: Decodable {
    let genre: String
    let id: UUID
}

private struct ThemeDTO: Decodable {
    let id: UUID
    let theme: String
}

private enum MangaStatusDTO: String, Decodable {
    case discontinued
    case onHiatus = "on_hiatus"
    case currentlyPublishing = "currently_publishing"
    case finished
    case none
}
