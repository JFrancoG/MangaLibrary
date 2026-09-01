//
//  CollectionModelsV2.swift
//  MangaLibrary
//

import Foundation
import SwiftData

extension MangaLibrarySchema.V2 {
    /// The versioned presentation data needed to reopen the shared manga detail offline.
    ///
    /// Collection owns this snapshot, while the remote catalog remains authoritative
    /// for future refreshes. Its manga identity is validated against the persisted
    /// collection pair before the actor accepts a mutation.
    struct MangaSnapshot: Codable, Equatable {
        enum Status: String, Codable, Equatable {
            case discontinued
            case onHiatus
            case publishing
            case finished
            case unspecified
        }

        struct Author: Codable, Equatable {
            enum Role: String, Codable, Equatable {
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

        struct Classification: Codable, Equatable {
            let id: UUID
            let name: String
        }

        let mangaID: Manga.ID
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

        func manga(knownTotalVolumes: Int64?) -> Manga {
            Manga(
                id: mangaID,
                title: title,
                titleEnglish: titleEnglish,
                titleJapanese: titleJapanese,
                synopsis: synopsis,
                score: score,
                status: status.mangaStatus,
                authors: authors.map(\.mangaAuthor),
                demographics: demographics.map(\.mangaClassification),
                genres: genres.map(\.mangaClassification),
                themes: themes.map(\.mangaClassification),
                totalVolumes: knownTotalVolumes,
                coverURL: coverURL
            )
        }
    }

    /// The current collection entry. V1 remains frozen for migration.
    @Model
    final class CollectionEntry {
        #Unique<CollectionEntry>([\.userID, \.mangaID])

        private(set) var userID: UUID
        private(set) var mangaID: Manga.ID
        @Attribute(.codable) private(set) var ownedVolumes: [Int64]
        private(set) var readingVolume: Int64?
        private(set) var isComplete: Bool
        private(set) var knownTotalVolumes: Int64?
        @Attribute(.codable) private(set) var confirmedState: MangaLibrarySchema.V1.CollectionSnapshot?
        private(set) var isTombstone: Bool
        @Attribute(.codable) private(set) var mangaSnapshot: MangaSnapshot?

        var state: MangaLibrarySchema.V1.CollectionSnapshot {
            MangaLibrarySchema.V1.CollectionSnapshot(
                ownedVolumes: ownedVolumes,
                readingVolume: readingVolume,
                isComplete: isComplete,
                knownTotalVolumes: knownTotalVolumes,
                isTombstone: isTombstone
            )
        }

        init(
            userID: UUID,
            mangaID: Manga.ID,
            state: MangaLibrarySchema.V1.CollectionSnapshot,
            confirmedState: MangaLibrarySchema.V1.CollectionSnapshot?,
            mangaSnapshot: MangaSnapshot? = nil
        ) {
            self.userID = userID
            self.mangaID = mangaID
            ownedVolumes = state.ownedVolumes
            readingVolume = state.readingVolume
            isComplete = state.isComplete
            knownTotalVolumes = state.knownTotalVolumes
            self.confirmedState = confirmedState
            isTombstone = state.isTombstone
            self.mangaSnapshot = mangaSnapshot
        }

        func apply(_ state: MangaLibrarySchema.V1.CollectionSnapshot, mangaSnapshot: MangaSnapshot?) {
            ownedVolumes = state.ownedVolumes
            readingVolume = state.readingVolume
            isComplete = state.isComplete
            knownTotalVolumes = state.knownTotalVolumes
            isTombstone = state.isTombstone

            if let mangaSnapshot {
                self.mangaSnapshot = mangaSnapshot
            }
        }
    }

    /// The current outbox operation. Its persisted shape is unchanged from V1.
    @Model
    final class CollectionOutboxOperation {
        #Unique<CollectionOutboxOperation>([\.operationID], [\.userID, \.mangaID, \.sequence])

        private(set) var operationID: UUID
        private(set) var userID: UUID
        private(set) var mangaID: Manga.ID
        private(set) var sequence: Int64
        @Attribute(.codable) private(set) var desiredState: MangaLibrarySchema.V1.CollectionSnapshot
        private(set) var state: MangaLibrarySchema.V1.CollectionOutboxState
        private(set) var retryCount: Int
        private(set) var nextRetryAt: Date?
        private(set) var isTombstone: Bool

        init(
            operationID: UUID,
            userID: UUID,
            mangaID: Manga.ID,
            sequence: Int64,
            desiredState: MangaLibrarySchema.V1.CollectionSnapshot,
            state: MangaLibrarySchema.V1.CollectionOutboxState = .queued,
            retryCount: Int = 0,
            nextRetryAt: Date? = nil
        ) {
            self.operationID = operationID
            self.userID = userID
            self.mangaID = mangaID
            self.sequence = sequence
            self.desiredState = desiredState
            self.state = state
            self.retryCount = retryCount
            self.nextRetryAt = nextRetryAt
            isTombstone = desiredState.isTombstone
        }

        func coalesce(sequence: Int64, desiredState: MangaLibrarySchema.V1.CollectionSnapshot) {
            self.sequence = sequence
            self.desiredState = desiredState
            state = .queued
            retryCount = 0
            nextRetryAt = nil
            isTombstone = desiredState.isTombstone
        }
    }
}

extension MangaLibrarySchema.V2.MangaSnapshot {
    init(manga: Manga) {
        mangaID = manga.id
        title = manga.title
        titleEnglish = manga.titleEnglish
        titleJapanese = manga.titleJapanese
        synopsis = manga.synopsis
        score = manga.score
        status = Status(manga.status)
        authors = manga.authors.map(Author.init)
        demographics = manga.demographics.map(Classification.init)
        genres = manga.genres.map(Classification.init)
        themes = manga.themes.map(Classification.init)
        coverURL = manga.coverURL
    }
}

private extension MangaLibrarySchema.V2.MangaSnapshot.Status {
    init(_ status: Manga.Status) {
        self = switch status {
        case .discontinued: .discontinued
        case .onHiatus: .onHiatus
        case .publishing: .publishing
        case .finished: .finished
        case .unspecified: .unspecified
        }
    }

    var mangaStatus: Manga.Status {
        switch self {
        case .discontinued: .discontinued
        case .onHiatus: .onHiatus
        case .publishing: .publishing
        case .finished: .finished
        case .unspecified: .unspecified
        }
    }
}

private extension MangaLibrarySchema.V2.MangaSnapshot.Author {
    init(_ author: Manga.Author) {
        id = author.id
        firstName = author.firstName
        lastName = author.lastName
        role = Role(author.role)
    }

    var mangaAuthor: Manga.Author {
        Manga.Author(id: id, firstName: firstName, lastName: lastName, role: role.mangaRole)
    }
}

private extension MangaLibrarySchema.V2.MangaSnapshot.Author.Role {
    init(_ role: Manga.Author.Role) {
        self = switch role {
        case .art: .art
        case .storyAndArt: .storyAndArt
        case .story: .story
        case .unspecified: .unspecified
        }
    }

    var mangaRole: Manga.Author.Role {
        switch self {
        case .art: .art
        case .storyAndArt: .storyAndArt
        case .story: .story
        case .unspecified: .unspecified
        }
    }
}

private extension MangaLibrarySchema.V2.MangaSnapshot.Classification {
    init(_ classification: Manga.Classification) {
        id = classification.id
        name = classification.name
    }

    var mangaClassification: Manga.Classification {
        Manga.Classification(id: id, name: name)
    }
}
