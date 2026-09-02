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
                AccountRootView(model: accountModel)
            }
            .accessibilityIdentifier("tab.account")
        }
        .tint(Color.brandPrimary)
        .task {
            await accountModel.restore()
        }
        .task(id: authenticatedUserID) {
            guard let authenticatedUserID else { return }

            // R1 is local-first: a remote failure leaves the observed SwiftData
            // snapshot untouched and adds no presentation state or retry loop.
            do {
                try await collectionSynchronization()
            } catch is CancellationError {
                return
            } catch {
                await accountModel.reconcileSessionAfterCollectionSync(
                    expectedUserID: authenticatedUserID
                )
            }
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
