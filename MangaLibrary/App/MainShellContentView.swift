//
//  MainShellContentView.swift
//  MangaLibrary
//

import SwiftData
import SwiftUI

struct MainShellContentView: View {
    let loadCatalogPage: CatalogModel.PageLoader
    let loadCatalogFilterOptions: CatalogModel.FilterOptionsLoader
    let accountModel: AccountModel
    let collectionMutation: CollectionMutation
    let collectionSynchronization: CollectionSynchronization
    let collectionBlockedOutcomeResolution: CollectionBlockedOutcomeResolution
    var readingPublication: ReadingPublicationLifecycle? = nil
    let authenticatedAuthority: SessionAuthority?

    @Environment(\.scenePhase) private var scenePhase
    @Query private var collectionOperations: [CollectionOutboxOperation]
    @State private var selectedTab: AppTab = .catalog
    @State private var transientCollectionNotice: AccountCollectionNotice? = nil

    var body: some View {
        let collectionAccess = accountModel.state.collectionAccess
        let synchronizationID = CollectionSynchronizationID(
            authority: authenticatedAuthority,
            operations: collectionOperations
        )
        let blockedOutcomeNotice = AccountCollectionNotice.persistedUploadOutcome(
            userID: authenticatedAuthority?.userID,
            operations: collectionOperations
        )

        TabView(selection: $selectedTab) {
            Tab("Catalog", systemImage: "magnifyingglass", value: .catalog) {
                CatalogRootView(
                    loadPage: loadCatalogPage,
                    loadFilterOptions: loadCatalogFilterOptions,
                    collectionAccess: collectionAccess,
                    collectionMutation: collectionMutation
                )
            }
            .accessibilityIdentifier("tab.catalog")

            Tab("Collection", systemImage: "books.vertical.fill", value: .collection) {
                CollectionRootView(access: collectionAccess, mutation: collectionMutation)
            }
            .accessibilityIdentifier("tab.collection")

            Tab("Account", systemImage: "person.crop.circle", value: .account) {
                AccountRootView(
                    model: accountModel,
                    transientCollectionNotice: transientCollectionNotice,
                    blockedOutcomeNotice: blockedOutcomeNotice,
                    collectionBlockedOutcomeResolution: collectionBlockedOutcomeResolution
                )
            }
            .accessibilityIdentifier("tab.account")
        }
        .tint(Color.brandPrimary)
        .safeAreaInset(edge: .bottom) {
            if let readingPublication, readingPublication.failure != nil {
                ReadingPublicationNoticeView {
                    readingPublication.retry()
                }
            }
        }
        .task {
            await accountModel.restore()
        }
        .task(id: ReadingPublicationTaskIdentity(isActive: scenePhase == .active, wakeID: readingPublication?.wakeID)) {
            guard scenePhase == .active else { return }
            if let authority = accountModel.state.authenticatedAuthority {
                await accountModel.reconcileSession(expectedAuthority: authority)
            }
            await readingPublication?.run()
        }
        .task(id: readingPublication?.failure?.identity) {
            guard let failure = readingPublication?.failure, let authority = failure.authority else { return }
            await accountModel.reconcileSession(expectedAuthority: authority, cause: failure.underlyingError)
        }
        .task(id: synchronizationID) {
            transientCollectionNotice = nil
            guard let authenticatedAuthority else { return }

            do {
                try await collectionSynchronization()
            } catch is CancellationError {
                return
            } catch {
                await accountModel.reconcileSession(expectedAuthority: authenticatedAuthority, cause: error)
                guard !Task.isCancelled, accountModel.state.authenticatedAuthority == authenticatedAuthority
                else { return }

                transientCollectionNotice = Self.transientCollectionNotice(
                    for: error,
                    userID: authenticatedAuthority.userID
                )
            }
        }
    }

    private static func transientCollectionNotice(for error: any Error, userID: UUID) -> AccountCollectionNotice? {
        if let uploadError = error as? CollectionOutboxUploadError, uploadError == .invalidVolumeState {
            return AccountCollectionNotice(userID: userID, reason: .unsupportedVolumeData)
        }
        guard let error = error as? CollectionSyncError else { return nil }

        return switch error {
        case .sessionChanged:
            nil
        case .authorizationDenied:
            AccountCollectionNotice(userID: userID, reason: .authorizationDenied)
        case .authenticationIncompatible:
            AccountCollectionNotice(userID: userID, reason: .authenticationIncompatible)
        case .unsupportedVolumeData:
            AccountCollectionNotice(userID: userID, reason: .unsupportedVolumeData)
        }
    }
}

private struct ReadingPublicationTaskIdentity: Equatable {
    let isActive: Bool
    let wakeID: UUID?
}

extension MainShellContentView {
    init(
        loadCatalogPage: @escaping CatalogModel.PageLoader,
        loadCatalogFilterOptions: @escaping CatalogModel.FilterOptionsLoader,
        accountModel: AccountModel,
        collectionMutation: CollectionMutation,
        collectionSynchronization: CollectionSynchronization,
        collectionBlockedOutcomeResolution: CollectionBlockedOutcomeResolution,
        readingPublication: ReadingPublicationLifecycle?,
        authenticatedAuthority: SessionAuthority?
    ) {
        self.loadCatalogPage = loadCatalogPage
        self.loadCatalogFilterOptions = loadCatalogFilterOptions
        self.accountModel = accountModel
        self.collectionMutation = collectionMutation
        self.collectionSynchronization = collectionSynchronization
        self.collectionBlockedOutcomeResolution = collectionBlockedOutcomeResolution
        self.readingPublication = readingPublication
        self.authenticatedAuthority = authenticatedAuthority
        _collectionOperations = Query(filter: CollectionOutboxOperation.userPredicate(
            userID: authenticatedAuthority?.userID
        ))
    }
}

#Preview("Scoped shell", traits: .modifier(CollectionPreviewModifier<CollectionPreviewScenarios.Shell>())) {
    @Previewable @Environment(\.modelContext) var modelContext
    CollectionPreviewSupport.shell(container: modelContext.container)
}
