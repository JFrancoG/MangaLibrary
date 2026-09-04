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

        /// Adopts a remote state when no later local intent owns the visible value.
        func applyRemote(_ state: MangaLibrarySchema.V1.CollectionSnapshot, mangaSnapshot: MangaSnapshot) {
            apply(state, mangaSnapshot: mangaSnapshot)
            confirmedState = state
        }

        /// Advances only the server baseline while a later local intent stays visible.
        func reconcileRemote(_ state: MangaLibrarySchema.V1.CollectionSnapshot, mangaSnapshot: MangaSnapshot) {
            confirmedState = state
            self.mangaSnapshot = mangaSnapshot
        }

        /// Records that the latest full remote snapshot no longer contains this manga.
        func confirmRemoteAbsence() {
            confirmedState = nil
        }

        /// Advances the server baseline without replacing a later optimistic state.
        func confirmUpload(_ state: MangaLibrarySchema.V1.CollectionSnapshot) {
            confirmedState = state
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

        func markSendingIfQueued() -> Bool {
            guard state == .queued else { return false }

            state = .sending
            return true
        }

        func markSendingIfRetryIsDue(at date: Date) -> Bool {
            guard state == .retry, let nextRetryAt, nextRetryAt <= date else { return false }

            state = .sending
            self.nextRetryAt = nil
            return true
        }

        func markRetryIfSending(nextRetryAt: Date) -> Bool {
            guard state == .sending else { return false }

            state = .retry
            if retryCount < Int.max {
                retryCount += 1
            }
            self.nextRetryAt = nextRetryAt
            return true
        }

        func markBlockedAuthIfUnsent() -> Bool {
            guard state == .queued || state == .retry else { return false }

            state = .blockedAuth
            nextRetryAt = nil
            return true
        }

        func markQueuedIfBlockedAuth() -> Bool {
            guard state == .blockedAuth else { return false }

            state = .queued
            nextRetryAt = nil
            return true
        }

        func markRejectedIfSending() -> Bool {
            guard state == .sending else { return false }

            state = .rejected
            nextRetryAt = nil
            return true
        }

        func markConfirmedIfRejected() -> Bool {
            guard state == .rejected else { return false }

            state = .confirmed
            retryCount = 0
            nextRetryAt = nil
            return true
        }

        func markConfirmedIfSending() -> Bool {
            guard state == .sending else { return false }

            state = .confirmed
            retryCount = 0
            nextRetryAt = nil
            return true
        }

        func markBlockedOutcomeIfSending() -> Bool {
            guard state == .sending else { return false }

            state = .blockedOutcome
            nextRetryAt = nil
            return true
        }

        func markConfirmedIfBlockedOutcome() -> Bool {
            guard state == .blockedOutcome else { return false }

            state = .confirmed
            retryCount = 0
            nextRetryAt = nil
            return true
        }

        /// Retains the highest sequence as a non-replayable cursor after an explicit logout discard.
        func resolveForLogoutDiscard() {
            state = .confirmed
            retryCount = 0
            nextRetryAt = nil
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
