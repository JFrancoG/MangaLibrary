//
//  Manga.swift
//  MangaLibrary
//

import Foundation

struct Manga: Identifiable, Equatable {
    let id: Int64
    let title: String
    let titleEnglish: String?
    let titleJapanese: String?
    let synopsis: String?
    let score: Double
    let status: Status
    let authors: [Author]
    let demographics: [Classification]
    let genres: [Classification]
    let themes: [Classification]
    let coverURL: URL?
}

extension Manga {
    enum Status: Equatable {
        case discontinued
        case onHiatus
        case publishing
        case finished
        case unspecified
    }

    struct Author: Identifiable, Equatable {
        enum Role: Equatable {
            case art
            case storyAndArt
            case story
            case unspecified
        }

        let id: UUID
        let firstName: String
        let lastName: String
        let role: Role
    }

    struct Classification: Identifiable, Equatable {
        let id: UUID
        let name: String
    }
}

extension Manga.Author {
    var nameComponents: PersonNameComponents {
        PersonNameComponents(
            givenName: firstName,
            familyName: lastName
        )
    }
}
