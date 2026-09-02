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

    @State private var selectedTab: AppTab = .catalog
    @State private var collectionNotice: AccountCollectionNotice? = nil

    var body: some View {
        let collectionAccess = accountModel.state.collectionAccess
        let authenticatedUserID = accountModel.state.authenticatedUserID

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
        .task(id: authenticatedUserID) {
            collectionNotice = nil
            guard let authenticatedUserID else { return }

            do {
                try await collectionSynchronization()
            } catch is CancellationError {
                return
            } catch {
                await accountModel.reconcileSessionAfterCollectionSync(expectedUserID: authenticatedUserID)
                guard !Task.isCancelled, accountModel.state.authenticatedUserID == authenticatedUserID else { return }

                collectionNotice = Self.collectionNotice(for: error, userID: authenticatedUserID)
            }
        }
    }

    private static func collectionNotice(for error: any Error, userID: UUID) -> AccountCollectionNotice? {
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
