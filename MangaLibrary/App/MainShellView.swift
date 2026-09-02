//
//  MainShellView.swift
//  MangaLibrary
//

import SwiftData
import SwiftUI

enum AppTab: Hashable {
    case catalog
    case collection
    case account
}

struct MainShellView: View {
    let loadCatalogPage: CatalogModel.PageLoader
    let loadCatalogFilterOptions: CatalogModel.FilterOptionsLoader
    let accountModel: AccountModel
    let collectionMutation: CollectionMutation
    let collectionSynchronization: CollectionSynchronization

    @Query private var collectionOperations: [CollectionOutboxOperation]
    @State private var selectedTab: AppTab = .catalog
    @State private var transientCollectionNotice: AccountCollectionNotice? = nil

    var body: some View {
        let collectionAccess = accountModel.state.collectionAccess
        let authenticatedUserID = accountModel.state.authenticatedUserID
        let synchronizationID = CollectionSynchronizationID(
            userID: authenticatedUserID,
            operations: collectionOperations
        )
        let collectionNotice = transientCollectionNotice ?? AccountCollectionNotice.persistedUploadOutcome(
            userID: authenticatedUserID,
            operations: collectionOperations
        )

        TabView(selection: $selectedTab) {
            Tab("Catalog", systemImage: "books.vertical", value: .catalog) {
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
                AccountRootView(model: accountModel, collectionNotice: collectionNotice)
            }
            .accessibilityIdentifier("tab.account")
        }
        .tint(Color.brandPrimary)
        .task {
            await accountModel.restore()
        }
        .task(id: synchronizationID) {
            transientCollectionNotice = nil
            guard let authenticatedUserID else { return }

            do {
                try await collectionSynchronization()
            } catch is CancellationError {
                return
            } catch {
                await accountModel.reconcileSessionAfterCollectionSync(expectedUserID: authenticatedUserID)
                guard !Task.isCancelled, accountModel.state.authenticatedUserID == authenticatedUserID else { return }

                transientCollectionNotice = Self.transientCollectionNotice(for: error, userID: authenticatedUserID)
            }
        }
    }

    private static func transientCollectionNotice(for error: any Error, userID: UUID) -> AccountCollectionNotice? {
        guard let error = error as? CollectionSyncError else { return nil }

        return switch error {
        case .sessionChanged:
            nil
        case .authorizationDenied:
            AccountCollectionNotice(userID: userID, reason: .authorizationDenied)
        case .authenticationIncompatible:
            AccountCollectionNotice(userID: userID, reason: .authenticationIncompatible)
        }
    }
}

extension AccountCollectionNotice {
    /// Keeps durable write uncertainty visible even when an earlier R1 read fails.
    static func persistedUploadOutcome(
        userID: UUID?,
        operations: [CollectionOutboxOperation]
    ) -> AccountCollectionNotice? {
        guard
            let userID,
            operations.contains(where: { $0.userID == userID && $0.state == .blockedOutcome })
        else { return nil }

        return AccountCollectionNotice(userID: userID, reason: .uploadOutcomeUnconfirmed)
    }
}

private struct CollectionSynchronizationID: Hashable {
    private struct OperationIdentity: Hashable {
        let operationID: UUID
        let sequence: Int64
    }

    let userID: UUID?
    private let operations: [OperationIdentity]

    init(userID: UUID?, operations: [CollectionOutboxOperation]) {
        self.userID = userID
        self.operations = operations
            .filter { $0.userID == userID }
            .map { OperationIdentity(operationID: $0.operationID, sequence: $0.sequence) }
            .sorted { lhs, rhs in
                if lhs.sequence != rhs.sequence { return lhs.sequence < rhs.sequence }
                return lhs.operationID.uuidString < rhs.operationID.uuidString
            }
    }
}

private extension AccountModel.State {
    var authenticatedUserID: UUID? {
        guard case let .authenticated(account, _) = self else { return nil }

        return account.id
    }
}

#Preview("Shell", traits: .modifier(CollectionPreviewModifier<CollectionPreviewScenarios.Shell>())) {
    @Previewable @Environment(\.modelContext) var modelContext
    CollectionPreviewSupport.shell(container: modelContext.container)
}
