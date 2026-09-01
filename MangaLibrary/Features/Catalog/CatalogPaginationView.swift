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
            ProgressView("Loading more results")
                .frame(maxWidth: .infinity)
                .accessibilityIdentifier("catalog.pagination.loading")
        case let .failure(_, reason):
            VStack(spacing: 10) {
                Label("Couldn't load more results", systemImage: "exclamationmark.triangle")
                .font(.headline)

                Text(reason.errorDescriptionResource)
                    .font(.subheadline)
                    .foregroundStyle(.textSecondary)

                Button("Retry") {
                    model.requestNextPageRetry()
                }
            }
            .multilineTextAlignment(.center)
            .frame(maxWidth: .infinity)
            .accessibilityIdentifier("catalog.pagination.error")
        case .end:
            Label("End of results", systemImage: "checkmark.circle")
                .font(.footnote)
                .foregroundStyle(.textSecondary)
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
                .init(items: CatalogPreviewSupport.mangas, pagination: .failure(page: 2, reason: .unavailable))
            )
        )
    )
    .padding()
}
