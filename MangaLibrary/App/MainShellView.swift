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

    @State private var selectedTab: AppTab = .catalog

    var body: some View {
        let collectionAccess = accountModel.state.collectionAccess

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
    }
}

#Preview("Shell", traits: .modifier(CollectionPreviewModifier<CollectionPreviewScenarios.Shell>())) {
    @Previewable @Environment(\.modelContext) var modelContext
    CollectionPreviewSupport.shell(container: modelContext.container)
}
