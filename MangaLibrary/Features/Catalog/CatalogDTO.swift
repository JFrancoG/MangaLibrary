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
            metadata: .init(page: metadata.page, per: metadata.per, total: metadata.total)
        )
    }
}

private struct PageMetadataDTO: Decodable {
    let page: Int64
    let per: Int64
    let total: Int64
}

private struct MangaDTO: Decodable {
    // Decode only values the product presents. Unknown remote fields can then
    // evolve without becoming false contract drift in this feature.
    let authors: [AuthorDTO]
    let demographics: [DemographicDTO]
    let genres: [GenreDTO]
    let id: Int64
    let mainPicture: String?
    let score: Double
    let status: MangaStatusDTO
    let sypnosis: String?
    let themes: [ThemeDTO]
    let title: String
    let titleEnglish: String?
    let titleJapanese: String?
    let volumes: Int64?

    func manga() -> Manga {
        Manga(
            id: id,
            title: title,
            titleEnglish: titleEnglish,
            titleJapanese: titleJapanese,
            synopsis: sypnosis,
            score: score,
            status: status.status,
            authors: authors.map(\.author),
            demographics: demographics.map(\.classification),
            genres: genres.map(\.classification),
            themes: themes.map(\.classification),
            totalVolumes: validatedTotalVolumes(),
            coverURL: validatedCoverURL()
        )
    }

    private func validatedTotalVolumes() -> Int64? {
        guard let volumes, volumes > 0 else { return nil }

        return volumes
    }

    private func validatedCoverURL() -> URL? {
        guard let mainPicture else { return nil }
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
    let id: UUID
    let firstName: String
    let lastName: String
    let role: AuthorRoleDTO

    var author: Manga.Author {
        Manga.Author(
            id: id,
            firstName: firstName,
            lastName: lastName,
            role: role.role
        )
    }
}

private enum AuthorRoleDTO: String, Decodable {
    case art = "Art"
    case storyAndArt = "Story & Art"
    case story = "Story"
    case unspecified = "None"

    var role: Manga.Author.Role {
        switch self {
        case .art: .art
        case .storyAndArt: .storyAndArt
        case .story: .story
        case .unspecified: .unspecified
        }
    }
}

private enum MangaStatusDTO: String, Decodable {
    case discontinued
    case onHiatus = "on_hiatus"
    case publishing = "currently_publishing"
    case finished
    case unspecified = "none"

    var status: Manga.Status {
        switch self {
        case .discontinued: .discontinued
        case .onHiatus: .onHiatus
        case .publishing: .publishing
        case .finished: .finished
        case .unspecified: .unspecified
        }
    }
}

private struct DemographicDTO: Decodable {
    let id: UUID
    let demographic: String

    var classification: Manga.Classification {
        Manga.Classification(id: id, name: demographic)
    }
}

private struct GenreDTO: Decodable {
    let id: UUID
    let genre: String

    var classification: Manga.Classification {
        Manga.Classification(id: id, name: genre)
    }
}

private struct ThemeDTO: Decodable {
    let id: UUID
    let theme: String

    var classification: Manga.Classification {
        Manga.Classification(id: id, name: theme)
    }
}
