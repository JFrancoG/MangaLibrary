#if DEBUG
import Foundation
import SwiftData

enum UITestingCollectionScenarios {
    static func uiTestingCollectionSynchronization(actor: CollectionMutationActor) -> CollectionSynchronization {
        let authority = AccountPreviewSupport.account.authority
        let commitGate = SessionCommitGate(activeAuthority: authority)
        let remoteEntry = CollectionRemoteEntry(
            remoteID: UUID(uuid: (102, 102, 102, 102, 102, 102, 102, 102, 102, 102, 102, 102, 102, 102, 102, 102)),
            manga: CatalogPreviewSupport.mangas[1],
            ownedVolumes: [1],
            readingVolume: nil,
            isComplete: false
        )

        return CollectionSynchronization(operation: {
            try await actor.importRemote([remoteEntry], authorization: commitGate.authorization(for: authority))
        })
    }

    static func uiTestingCollectionAuthorizationFailure() -> CollectionSynchronization {
        CollectionSynchronization(operation: {
            throw CollectionSyncError.authorizationDenied(origin: .collectionSnapshot(attempt: 1), statusCode: 403)
        })
    }

    static func seedUITestingMountedCollectionDetail(in container: ModelContainer) throws {
        let context = ModelContext(container)
        let manga = CatalogPreviewSupport.mangas[1]
        let state = CollectionSnapshot(
            ownedVolumes: [1],
            readingVolume: 1,
            isComplete: false,
            knownTotalVolumes: manga.totalVolumes,
            isTombstone: false
        )
        context.insert(
            CollectionEntry(
                userID: AccountPreviewSupport.account.id,
                mangaID: manga.id,
                state: state,
                confirmedState: state,
                mangaSnapshot: CollectionMangaSnapshot(manga: manga)
            )
        )
        try context.save()
    }

    static func uiTestingCollectionDetailUpdate(actor: CollectionMutationActor) -> CollectionSynchronization {
        let authority = AccountPreviewSupport.account.authority
        let commitGate = SessionCommitGate(activeAuthority: authority)
        let manga = CatalogPreviewSupport.mangas[1]
        let remoteEntry = CollectionRemoteEntry(
            remoteID: UUID(uuid: (103, 103, 103, 103, 103, 103, 103, 103, 103, 103, 103, 103, 103, 103, 103, 103)),
            manga: manga,
            ownedVolumes: [1, 12],
            readingVolume: 8,
            isComplete: false
        )

        return CollectionSynchronization(operation: {
            try await actor.importRemote([remoteEntry], authorization: commitGate.authorization(for: authority))
        })
    }

    static func seedUITestingBlockedOutcomes(in container: ModelContainer) throws {
        let context = ModelContext(container)
        let updateManga = CatalogPreviewSupport.mangas[0]
        let updateState = CollectionSnapshot(
            ownedVolumes: [1, 3],
            readingVolume: 2,
            isComplete: false,
            knownTotalVolumes: updateManga.totalVolumes,
            isTombstone: false
        )
        context.insert(
            CollectionEntry(
                userID: AccountPreviewSupport.account.id,
                mangaID: updateManga.id,
                state: updateState,
                confirmedState: CollectionSnapshot(
                    ownedVolumes: [1],
                    readingVolume: 1,
                    isComplete: false,
                    knownTotalVolumes: updateManga.totalVolumes,
                    isTombstone: false
                ),
                mangaSnapshot: CollectionMangaSnapshot(manga: updateManga)
            )
        )
        context.insert(
            CollectionOutboxOperation(
                operationID: UUID(uuidString: "C9C9C9C9-C9C9-C9C9-C9C9-C9C9C9C9C9C9")!,
                userID: AccountPreviewSupport.account.id,
                mangaID: updateManga.id,
                sequence: 1,
                desiredState: updateState,
                state: .blockedOutcome
            )
        )

        let deletionManga = CatalogPreviewSupport.mangas[1]
        let deletionState = CollectionSnapshot(
            ownedVolumes: [1],
            readingVolume: 1,
            isComplete: false,
            knownTotalVolumes: deletionManga.totalVolumes,
            isTombstone: true
        )
        context.insert(
            CollectionEntry(
                userID: AccountPreviewSupport.account.id,
                mangaID: deletionManga.id,
                state: deletionState,
                confirmedState: CollectionSnapshot(
                    ownedVolumes: [1],
                    readingVolume: 1,
                    isComplete: false,
                    knownTotalVolumes: deletionManga.totalVolumes,
                    isTombstone: false
                ),
                mangaSnapshot: CollectionMangaSnapshot(manga: deletionManga)
            )
        )
        context.insert(
            CollectionOutboxOperation(
                operationID: UUID(uuidString: "CACACACA-CACA-CACA-CACA-CACACACACACA")!,
                userID: AccountPreviewSupport.account.id,
                mangaID: deletionManga.id,
                sequence: 1,
                desiredState: deletionState,
                state: .blockedOutcome
            )
        )
        try context.save()
    }

    static func seedUITestingPendingLogout(in container: ModelContainer) throws {
        let context = ModelContext(container)
        let manga = CatalogPreviewSupport.mangas[0]
        let confirmedState = CollectionSnapshot(
            ownedVolumes: [1],
            readingVolume: 1,
            isComplete: false,
            knownTotalVolumes: manga.totalVolumes,
            isTombstone: false
        )
        let localState = CollectionSnapshot(
            ownedVolumes: [1, 2],
            readingVolume: 2,
            isComplete: false,
            knownTotalVolumes: manga.totalVolumes,
            isTombstone: false
        )
        context.insert(
            CollectionEntry(
                userID: AccountPreviewSupport.account.id,
                mangaID: manga.id,
                state: localState,
                confirmedState: confirmedState,
                mangaSnapshot: CollectionMangaSnapshot(manga: manga)
            )
        )
        context.insert(
            CollectionOutboxOperation(
                operationID: UUID(uuidString: "DADADADA-DADA-DADA-DADA-DADADADADADA")!,
                userID: AccountPreviewSupport.account.id,
                mangaID: manga.id,
                sequence: 1,
                desiredState: localState
            )
        )
        try context.save()
    }

    static func uiTestingBlockedOutcomeResolution(
        actor: CollectionMutationActor
    ) -> CollectionBlockedOutcomeResolution {
        let authority = AccountPreviewSupport.account.authority
        let commitGate = SessionCommitGate(activeAuthority: authority)
        let authorization = SessionRequestAuthorization(
            authority: authority,
            accessToken: "synthetic-ui-access",
            commitAuthorization: commitGate.authorization(for: authority)
        )
        let coordinator = CollectionOutcomeResolutionCoordinator(
            authorize: { authorization },
            validateAuthorization: { candidate in
                guard candidate.authority == authority else { return false }
                do {
                    try candidate.commitAuthorization.perform {}
                    return true
                } catch {
                    return false
                }
            },
            recoverAuthorization: { _ in
                throw CollectionBlockedOutcomeError.unavailable
            },
            loadContext: { operationID, commitAuthorization in
                try await actor.blockedOutcomeContext(operationID: operationID, authorization: commitAuthorization)
            },
            fetchRemoteEntry: { mangaID, _ in
                guard mangaID == CatalogPreviewSupport.mangas[0].id else { return nil }
                let manga = CatalogPreviewSupport.mangas[0]
                return CollectionRemoteEntry(
                    remoteID: UUID(uuidString: "CBCBCBCB-CBCB-CBCB-CBCB-CBCBCBCBCBCB")!,
                    manga: manga,
                    ownedVolumes: [1],
                    readingVolume: 1,
                    isComplete: false
                )
            },
            validateEvidence: { remoteEntry, mangaID in
                try await actor.blockedOutcomeEvidence(remoteEntry: remoteEntry, mangaID: mangaID)
            },
            resolveStore: { context, evidence, decision, commitAuthorization, operationID in
                try await actor.resolveBlockedOutcome(
                    context,
                    evidence: evidence,
                    decision: decision,
                    authorization: commitAuthorization,
                    newOperationID: operationID
                )
            }
        )
        return CollectionBlockedOutcomeResolution(coordinator: coordinator)
    }
}
#endif
