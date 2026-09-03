//
//  MangaDTO.swift
//  MangaLibrary
//

import Foundation

/// The shared wire representation embedded by Catalog and Collection responses.
struct MangaDTO: Decodable {
    // Decode only values the product presents. Unknown remote fields can then
    // evolve without becoming false contract drift in either consumer.
    private let authors: [AuthorDTO]
    private let demographics: [DemographicDTO]
    private let genres: [GenreDTO]
    private let id: Int64
    private let mainPicture: String?
    private let score: Double
    private let status: MangaStatusDTO
    private let sypnosis: String?
    private let themes: [ThemeDTO]
    private let title: String
    private let titleEnglish: String?
    private let titleJapanese: String?
    private let volumes: Int64?

    /// Preserves the exact optional wire value for consumers with strict invariants.
    var reportedTotalVolumes: Int64? { volumes }

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
        CollectionVolumePolicy.supportedKnownTotal(volumes)
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
