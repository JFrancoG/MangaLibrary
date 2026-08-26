//
//  CatalogPaginationView.swift
//  MangaLibrary
//

import SwiftUI

struct CatalogPaginationView: View {
    let pagination: CatalogModel.Pagination
    let model: CatalogModel

    var body: some View {
        switch pagination {
        case .ready:
            EmptyView()
        case .loading:
            ProgressView("Loading more manga")
                .frame(maxWidth: .infinity)
                .accessibilityIdentifier("catalog.pagination.loading")
        case .failure:
            VStack(spacing: 10) {
                Label(
                    "Couldn't load more manga",
                    systemImage: "wifi.exclamationmark"
                )
                .font(.headline)

                Text("Your existing results are still available.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)

                Button("Retry") {
                    model.requestNextPageRetry()
                }
            }
            .multilineTextAlignment(.center)
            .frame(maxWidth: .infinity)
            .accessibilityIdentifier("catalog.pagination.error")
        case .end:
            Label("End of catalog", systemImage: "checkmark.circle")
                .font(.footnote)
                .foregroundStyle(.secondary)
                .frame(maxWidth: .infinity)
                .accessibilityIdentifier("catalog.pagination.end")
        }
    }
}

#Preview("Additional page failure") {
    CatalogPaginationView(
        pagination: .failure(page: 2, reason: .unavailable),
        model: CatalogPreviewSupport.model(
            state: .content(
                .init(
                    items: CatalogPreviewSupport.mangas,
                    pagination: .failure(page: 2, reason: .unavailable)
                )
            )
        )
    )
    .padding()
}
