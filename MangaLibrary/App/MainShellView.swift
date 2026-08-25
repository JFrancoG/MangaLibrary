//
//  MainShellView.swift
//  MangaLibrary
//

import SwiftUI

enum AppTab: Hashable {
    case catalog
    case collection
    case account
}

struct MainShellView: View {
    let catalogClient: CatalogAPIClient

    @State private var selectedTab: AppTab = .catalog

    var body: some View {
        TabView(selection: $selectedTab) {
            Tab("Catalog", systemImage: "books.vertical", value: .catalog) {
                CatalogRootView(client: catalogClient)
            }
            .accessibilityIdentifier("tab.catalog")

            Tab("Collection", systemImage: "books.vertical.fill", value: .collection) {
                NavigationSplitView {
                    ContentUnavailableView(
                        "Collection is not available yet",
                        systemImage: "books.vertical",
                        description: Text("Collection arrives in a later Advanced unit.")
                    )
                    .accessibilityIdentifier("collection.unavailable")
                    .navigationTitle("Collection")
                } detail: {
                    ContentUnavailableView(
                        "Collection is not available yet",
                        systemImage: "books.vertical"
                    )
                }
            }
            .accessibilityIdentifier("tab.collection")

            Tab("Account", systemImage: "person.crop.circle", value: .account) {
                NavigationStack {
                    ContentUnavailableView(
                        "Account is not available yet",
                        systemImage: "person.crop.circle",
                        description: Text("Account arrives in a later Advanced unit.")
                    )
                    .accessibilityIdentifier("account.unavailable")
                    .navigationTitle("Account")
                }
            }
            .accessibilityIdentifier("tab.account")
        }
    }
}

#Preview("Shell") {
    MainShellView(catalogClient: CatalogPreviewSupport.catalogClient)
}
