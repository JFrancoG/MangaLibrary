//
//  CollectionBlockedOutcomePreviewSupport.swift
//  MangaLibrary
//

import SwiftData
import SwiftUI

struct CollectionBlockedOutcomePreviewModifier<Scenario: CollectionBlockedOutcomePreviewScenario>: PreviewModifier {
    static func makeSharedContext() throws -> ModelContainer {
        let container = try MangaLibrarySchema.makeContainer(isStoredInMemoryOnly: true)
        try CollectionBlockedOutcomePreviewFixtures.seed(Scenario.seed, in: container)
        return container
    }

    func body(content: Content, context: ModelContainer) -> some View { content.modelContainer(context) }
}

protocol CollectionBlockedOutcomePreviewScenario {
    static var seed: CollectionBlockedOutcomePreviewSeed { get }
}

enum CollectionBlockedOutcomePreviewScenarios {
    enum List: CollectionBlockedOutcomePreviewScenario {
        static let seed = CollectionBlockedOutcomePreviewSeed.list
    }

    enum Empty: CollectionBlockedOutcomePreviewScenario {
        static let seed = CollectionBlockedOutcomePreviewSeed.empty
    }
}

enum CollectionBlockedOutcomePreviewSeed: Equatable {
    case empty
    case list
}

enum CollectionBlockedOutcomePreviewFixtures {
    static let userID = UUID(uuidString: "11111111-1111-1111-1111-111111111111")!
    static let otherUserID = UUID(uuidString: "99999999-9999-9999-9999-999999999999")!
    static let generation = UUID(uuidString: "22222222-2222-2222-2222-222222222222")!
    static let authority = SessionAuthority(userID: userID, generation: generation)
    static let operationID = UUID(uuidString: "33333333-3333-3333-3333-333333333333")!
    static let deletionOperationID = UUID(uuidString: "44444444-4444-4444-4444-444444444444")!
    static let laterOperationID = UUID(uuidString: "55555555-5555-5555-5555-555555555555")!

    static let deviceState = CollectionSnapshot(
        ownedVolumes: [1, 3],
        readingVolume: 2,
        isComplete: false,
        knownTotalVolumes: 12,
        isTombstone: false
    )
    static let remoteState = CollectionSnapshot(
        ownedVolumes: [1, 2],
        readingVolume: 1,
        isComplete: false,
        knownTotalVolumes: 10,
        isTombstone: false
    )
    static let deletionState = CollectionSnapshot(
        ownedVolumes: [1, 2],
        readingVolume: 2,
        isComplete: false,
        knownTotalVolumes: 8,
        isTombstone: true
    )
    static let laterState = CollectionSnapshot(
        ownedVolumes: [1, 3, 4],
        readingVolume: 3,
        isComplete: false,
        knownTotalVolumes: 12,
        isTombstone: false
    )

    static let mangaSnapshot = CollectionMangaSnapshot(
        mangaID: 1,
        title: "The Library at Dusk",
        titleEnglish: nil,
        titleJapanese: nil,
        synopsis: nil,
        score: 8.4,
        status: .publishing,
        authors: [],
        demographics: [],
        genres: [],
        themes: [],
        coverURL: nil
    )
    static let deletionMangaSnapshot = CollectionMangaSnapshot(
        mangaID: 2,
        title: "A Very Long Manga Title for the Pending Deletion Review",
        titleEnglish: nil,
        titleJapanese: nil,
        synopsis: nil,
        score: 7.9,
        status: .finished,
        authors: [],
        demographics: [],
        genres: [],
        themes: [],
        coverURL: nil
    )

    static let presentReview = CollectionBlockedOutcomeReview(
        context: CollectionBlockedOutcomeContext(
            operation: CollectionBlockedOutcomeOperationReference(
                authority: authority,
                operationID: operationID,
                userID: userID,
                mangaID: 1,
                sequence: 1,
                retryCount: 0,
                desiredState: deviceState
            ),
            deviceState: deviceState,
            mangaSnapshot: mangaSnapshot,
            laterIntent: nil
        ),
        evidence: .present(state: remoteState, mangaSnapshot: mangaSnapshot)
    )

    static let absentReview = CollectionBlockedOutcomeReview(
        context: CollectionBlockedOutcomeContext(
            operation: CollectionBlockedOutcomeOperationReference(
                authority: authority,
                operationID: deletionOperationID,
                userID: userID,
                mangaID: 2,
                sequence: 1,
                retryCount: 0,
                desiredState: deletionState
            ),
            deviceState: deletionState,
            mangaSnapshot: deletionMangaSnapshot,
            laterIntent: nil
        ),
        evidence: .absent
    )

    static let laterIntentReview = CollectionBlockedOutcomeReview(
        context: CollectionBlockedOutcomeContext(
            operation: presentReview.context.operation,
            deviceState: laterState,
            mangaSnapshot: mangaSnapshot,
            laterIntent: CollectionBlockedOutcomeLaterIntent(
                operationID: laterOperationID,
                sequence: 2,
                retryCount: 0,
                nextRetryAt: nil,
                state: .queued,
                desiredState: laterState
            )
        ),
        evidence: presentReview.evidence
    )

    static let resolution = CollectionBlockedOutcomeResolution(
        review: { operationID, authority in
            guard authority == Self.authority else { throw CollectionBlockedOutcomeError.sessionChanged }
            switch operationID {
            case Self.operationID:
                return Self.presentReview
            case Self.deletionOperationID:
                return Self.absentReview
            default:
                throw CollectionBlockedOutcomeError.staleOperation
            }
        },
        resolve: { review, decision in
            if review.context.hasLaterIntent {
                guard decision == .keepDevice, let laterIntent = review.context.laterIntent else {
                    throw CollectionBlockedOutcomeError.laterIntentRequiresDeviceVersion
                }
                return .continuedExistingIntent(operationID: laterIntent.operationID, sequence: laterIntent.sequence)
            }
            return decision == .useRemote ? .adoptedRemote : .effectAlreadyConfirmed
        }
    )

    static func seed(_ seed: CollectionBlockedOutcomePreviewSeed, in container: ModelContainer) throws {
        guard seed == .list else { return }

        let context = ModelContext(container)
        context.insert(
            CollectionEntry(
                userID: userID,
                mangaID: 1,
                state: deviceState,
                confirmedState: remoteState,
                mangaSnapshot: mangaSnapshot
            )
        )
        context.insert(
            CollectionOutboxOperation(
                operationID: operationID,
                userID: userID,
                mangaID: 1,
                sequence: 1,
                desiredState: deviceState,
                state: .blockedOutcome
            )
        )
        context.insert(
            CollectionEntry(
                userID: userID,
                mangaID: 2,
                state: deletionState,
                confirmedState: remoteState,
                mangaSnapshot: deletionMangaSnapshot
            )
        )
        context.insert(
            CollectionOutboxOperation(
                operationID: deletionOperationID,
                userID: userID,
                mangaID: 2,
                sequence: 1,
                desiredState: deletionState,
                state: .blockedOutcome
            )
        )
        context.insert(
            CollectionOutboxOperation(
                operationID: laterOperationID,
                userID: userID,
                mangaID: 3,
                sequence: 1,
                desiredState: deviceState,
                state: .queued
            )
        )
        context.insert(
            CollectionOutboxOperation(
                operationID: UUID(uuidString: "AAAAAAAA-AAAA-AAAA-AAAA-AAAAAAAAAAAA")!,
                userID: otherUserID,
                mangaID: 4,
                sequence: 1,
                desiredState: deviceState,
                state: .blockedOutcome
            )
        )
        try context.save()
    }
}
