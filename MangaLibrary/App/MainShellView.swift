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
    let collectionBlockedOutcomeResolution: CollectionBlockedOutcomeResolution
    var readingPublication: ReadingPublicationLifecycle? = nil

    var body: some View {
        MainShellContentView(
            loadCatalogPage: loadCatalogPage,
            loadCatalogFilterOptions: loadCatalogFilterOptions,
            accountModel: accountModel,
            collectionMutation: collectionMutation,
            collectionSynchronization: collectionSynchronization,
            collectionBlockedOutcomeResolution: collectionBlockedOutcomeResolution,
            readingPublication: readingPublication,
            authenticatedAuthority: accountModel.state.authenticatedAuthority
        )
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

struct CollectionSynchronizationID: Hashable {
    private struct OperationIdentity: Hashable {
        let operationID: UUID
        let sequence: Int64
    }

    let authority: SessionAuthority?
    private let operations: [OperationIdentity]
    private let blockedOutcomeOperations: [OperationIdentity]

    init(authority: SessionAuthority?, operations: [CollectionOutboxOperation]) {
        self.authority = authority
        self.operations = operations
            .filter { $0.userID == authority?.userID }
            .map { OperationIdentity(operationID: $0.operationID, sequence: $0.sequence) }
            .sorted { lhs, rhs in
                if lhs.sequence != rhs.sequence {
                    return lhs.sequence < rhs.sequence
                }
                return lhs.operationID.uuidString < rhs.operationID.uuidString
            }
        blockedOutcomeOperations = operations
            .filter { $0.userID == authority?.userID && $0.state == .blockedOutcome }
            .map { OperationIdentity(operationID: $0.operationID, sequence: $0.sequence) }
            .sorted { lhs, rhs in
                if lhs.sequence != rhs.sequence {
                    return lhs.sequence < rhs.sequence
                }
                return lhs.operationID.uuidString < rhs.operationID.uuidString
            }
    }
}

extension AccountModel.State {
    var authenticatedAuthority: SessionAuthority? {
        guard case let .authenticated(account, _) = self else { return nil }

        return account.authority
    }
}

#Preview("Shell", traits: .modifier(CollectionPreviewModifier<CollectionPreviewScenarios.Shell>())) {
    @Previewable @Environment(\.modelContext) var modelContext
    CollectionPreviewSupport.shell(container: modelContext.container)
}
