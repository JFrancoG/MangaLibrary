//
//  MangaLibraryApp.swift
//  MangaLibrary
//
//  Created by Jesús Franco on 15.08.2026.
//

import SwiftData
import SwiftUI

@main
struct MangaLibraryApp: App {
    private let modelContainer: ModelContainer
    private let collectionMutation: CollectionMutation
    private let collectionSynchronization: CollectionSynchronization
    private let collectionBlockedOutcomeResolution: CollectionBlockedOutcomeResolution
    private let loadCatalogPage: CatalogModel.PageLoader
    private let loadCatalogFilterOptions: CatalogModel.FilterOptionsLoader
    @State private var accountModel: AccountModel
#if DEBUG
    private let presentsUITestingCollectionDetailProjection: Bool
    private let presentsUITestingMountedCollectionDetail: Bool
    private let uiTestingCollectionDetailUpdate: CollectionSynchronization
#endif

    var body: some Scene {
        WindowGroup {
            let shell = MainShellView(
                loadCatalogPage: loadCatalogPage,
                loadCatalogFilterOptions: loadCatalogFilterOptions,
                accountModel: accountModel,
                collectionMutation: collectionMutation,
                collectionSynchronization: collectionSynchronization,
                collectionBlockedOutcomeResolution: collectionBlockedOutcomeResolution
            )
#if DEBUG
            if presentsUITestingCollectionDetailProjection {
                Self.uiTestingCollectionDetailProjection(mutation: collectionMutation)
            } else if presentsUITestingMountedCollectionDetail {
                Self.uiTestingMountedCollectionDetail(
                    mutation: collectionMutation,
                    update: uiTestingCollectionDetailUpdate
                )
            } else {
                shell
            }
#else
            shell
#endif
        }
        .modelContainer(modelContainer)
    }
}

extension MangaLibraryApp {
    init() {
        let processArguments = ProcessInfo.processInfo.arguments
        if processArguments.contains("-ui-testing") {
#if DEBUG
            // UI automation owns deterministic scenarios and cannot fall
            // through to production networking.
            do {
                let testsCollectionDetailProjection = processArguments.contains(
                    "-ui-testing-collection-detail-projection"
                )
                let testsMountedCollectionDetail = processArguments.contains("-ui-testing-mounted-collection-detail")
                let testsBlockedOutcomeResolution = processArguments.contains("-ui-testing-blocked-outcome-resolution")
                let disablesCollectionSynchronization =
                    testsCollectionDetailProjection
                    || testsMountedCollectionDetail
                    || testsBlockedOutcomeResolution
                let container = try MangaLibrarySchema.makeContainer(isStoredInMemoryOnly: true)
                if testsMountedCollectionDetail {
                    try Self.seedUITestingMountedCollectionDetail(in: container)
                }
                if testsBlockedOutcomeResolution {
                    try Self.seedUITestingBlockedOutcomes(in: container)
                }
                let accountState: AccountModel.State = testsMountedCollectionDetail || testsBlockedOutcomeResolution
                    ? .authenticated(AccountPreviewSupport.account, notice: nil)
                    : .signedOut(failure: nil)
                let account = AccountPreviewSupport.model(state: accountState)
                let mutationActor = CollectionMutationActor(modelContainer: container)
                modelContainer = container
                collectionMutation = CollectionMutation(
                    actor: mutationActor,
                    accountModel: account,
                    sessionAuthorization: .deterministic
                )
                let synchronization: CollectionSynchronization
                if processArguments.contains("-ui-testing-collection-authorization-denied") {
                    synchronization = Self.uiTestingCollectionAuthorizationFailure()
                } else if disablesCollectionSynchronization {
                    synchronization = .disabled
                } else {
                    synchronization = Self.uiTestingCollectionSynchronization(actor: mutationActor)
                }
                collectionSynchronization = synchronization
                collectionBlockedOutcomeResolution = testsBlockedOutcomeResolution
                    ? Self.uiTestingBlockedOutcomeResolution(actor: mutationActor)
                    : .disabled
                presentsUITestingCollectionDetailProjection = testsCollectionDetailProjection
                presentsUITestingMountedCollectionDetail = testsMountedCollectionDetail
                uiTestingCollectionDetailUpdate = testsMountedCollectionDetail
                    ? Self.uiTestingCollectionDetailUpdate(actor: mutationActor)
                    : .disabled
                loadCatalogPage = CatalogPreviewSupport.pageLoader
                loadCatalogFilterOptions = CatalogPreviewSupport.filterOptionsLoader
                _accountModel = State(initialValue: account)
                return
            } catch {
                preconditionFailure("Manga Library could not create its UI testing data store.")
            }
#else
            preconditionFailure("UI testing data is unavailable in production builds.")
#endif
        }

        do {
            let composition = try AppComposition.live()
            let catalogClient = composition.catalogClient
            let account = AccountModel(
                operations: .live(controller: composition.sessionController, register: composition.registerUser)
            )
            modelContainer = composition.modelContainer
            collectionMutation = CollectionMutation(
                actor: composition.collectionMutations,
                accountModel: account,
                sessionAuthorization: CollectionSessionAuthorization(sessionController: composition.sessionController)
            )
            collectionSynchronization = composition.collectionSynchronization
            collectionBlockedOutcomeResolution = composition.collectionBlockedOutcomeResolution
#if DEBUG
            presentsUITestingCollectionDetailProjection = false
            presentsUITestingMountedCollectionDetail = false
            uiTestingCollectionDetailUpdate = .disabled
#endif
            loadCatalogPage = { request in
                try await catalogClient.fetch(request)
            }
            loadCatalogFilterOptions = {
                try await catalogClient.fetchFilterOptions()
            }
            _accountModel = State(initialValue: account)
        } catch {
            preconditionFailure("Manga Library could not create its app dependencies.")
        }
    }

#if DEBUG
    private static func uiTestingCollectionSynchronization(
        actor: CollectionMutationActor
    ) -> CollectionSynchronization {
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

    private static func uiTestingCollectionAuthorizationFailure() -> CollectionSynchronization {
        CollectionSynchronization(operation: {
            throw CollectionSyncError.authorizationDenied(origin: .collectionSnapshot(attempt: 1), statusCode: 403)
        })
    }

    private static func uiTestingCollectionDetailProjection(mutation: CollectionMutation) -> some View {
        let manga = CatalogPreviewSupport.mangas[1]
        let state = CollectionSnapshot(
            ownedVolumes: [1, 12],
            readingVolume: 8,
            isComplete: false,
            knownTotalVolumes: manga.totalVolumes,
            isTombstone: false
        )

        return NavigationStack {
            CollectionEntryDetailView(
                mangaID: manga.id,
                mangaSnapshot: CollectionMangaSnapshot(manga: manga),
                state: state,
                scope: CollectionUserScope(
                    userID: AccountPreviewSupport.account.id,
                    authority: AccountPreviewSupport.account.authority
                ),
                restriction: nil,
                mutation: mutation
            )
        }
    }

    private static func uiTestingMountedCollectionDetail(
        mutation: CollectionMutation,
        update: CollectionSynchronization
    ) -> some View {
        CollectionUserRootView(
            scope: CollectionUserScope(
                userID: AccountPreviewSupport.account.id,
                authority: AccountPreviewSupport.account.authority
            ),
            restriction: nil,
            mutation: mutation
        )
        .safeAreaInset(edge: .bottom) {
            Button {
                Task {
                    do {
                        try await update()
                    } catch {
                        preconditionFailure("The deterministic Collection update failed.")
                    }
                }
            } label: {
                Text(verbatim: "Apply synchronized state")
            }
            .buttonStyle(.borderedProminent)
            .accessibilityIdentifier("ui-testing.collection.apply-synchronized-state")
            .padding()
        }
    }

    private static func seedUITestingMountedCollectionDetail(in container: ModelContainer) throws {
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

    private static func uiTestingCollectionDetailUpdate(actor: CollectionMutationActor) -> CollectionSynchronization {
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

    private static func seedUITestingBlockedOutcomes(in container: ModelContainer) throws {
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

    private static func uiTestingBlockedOutcomeResolution(
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
#endif
}
