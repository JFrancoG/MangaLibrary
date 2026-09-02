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
        let authenticatedAuthority = accountModel.state.authenticatedAuthority

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
        .task(id: authenticatedAuthority) {
            collectionNotice = nil
            guard let authenticatedAuthority else { return }

            do {
                try await collectionSynchronization()
            } catch is CancellationError {
                return
            } catch {
                await accountModel.reconcileSession(expectedAuthority: authenticatedAuthority, cause: error)
                guard
                    !Task.isCancelled,
                    accountModel.state.authenticatedAuthority == authenticatedAuthority
                else { return }

                collectionNotice = Self.collectionNotice(for: error, userID: authenticatedAuthority.userID)
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
    var authenticatedAuthority: SessionAuthority? {
        guard case let .authenticated(account, _) = self else { return nil }

        return account.authority
    }
}

#Preview("Shell", traits: .modifier(CollectionPreviewModifier<CollectionPreviewScenarios.Shell>())) {
    @Previewable @Environment(\.modelContext) var modelContext
    CollectionPreviewSupport.shell(container: modelContext.container)
}
