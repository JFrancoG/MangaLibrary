//
//  CollectionBlockedOutcomesView.swift
//  MangaLibrary
//

import SwiftData
import SwiftUI

struct CollectionBlockedOutcomesView: View {
    @Query private var operations: [CollectionOutboxOperation]
    @Query private var entries: [CollectionEntry]

    let authority: SessionAuthority
    let resolution: CollectionBlockedOutcomeResolution

    var body: some View {
        Group {
            if operations.isEmpty {
                ContentUnavailableView(
                    "No changes need review",
                    systemImage: "checkmark.circle",
                    description: Text("Your confirmed collection and pending changes need no decision right now.")
                )
                .accessibilityIdentifier("collection.blocked-outcomes.empty")
            } else {
                List(operations, id: \.operationID) { operation in
                    NavigationLink {
                        CollectionBlockedOutcomeReviewView(
                            operationID: operation.operationID,
                            authority: authority,
                            resolution: resolution
                        )
                    } label: {
                        operationLabel(operation)
                    }
                    .accessibilityIdentifier("collection.blocked-outcomes.operation.\(operation.mangaID)")
                }
                .scrollContentBackground(.hidden)
            }
        }
        .background(.canvas)
        .navigationTitle("Review changes")
        .navigationBarTitleDisplayMode(.inline)
    }

    private func operationLabel(_ operation: CollectionOutboxOperation) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            if let title = title(for: operation.mangaID) {
                Text(title)
                    .font(.headline)
                    .foregroundStyle(.textPrimary)
            } else {
                Text("Manga #\(operation.mangaID)")
                    .font(.headline)
                    .foregroundStyle(.textPrimary)
            }

            Text(operationDescription(operation))
                .font(.subheadline)
                .foregroundStyle(.textSecondary)
        }
        .accessibilityElement(children: .combine)
    }

    private func title(for mangaID: Manga.ID) -> String? {
        entries.first(where: { $0.mangaID == mangaID })?.mangaSnapshot?.title
    }

    private func operationDescription(_ operation: CollectionOutboxOperation) -> LocalizedStringResource {
        operation.isTombstone ? "Deletion not confirmed" : "Update not confirmed"
    }
}

extension CollectionBlockedOutcomesView {
    init(authority: SessionAuthority, resolution: CollectionBlockedOutcomeResolution) {
        self.authority = authority
        self.resolution = resolution
        _operations = Query(
            filter: CollectionOutboxOperation.blockedOutcomePredicate(userID: authority.userID),
            sort: [
                SortDescriptor(\CollectionOutboxOperation.sequence),
                SortDescriptor(\CollectionOutboxOperation.mangaID),
            ]
        )
        _entries = Query(
            filter: CollectionEntry.userPredicate(userID: authority.userID),
            sort: [SortDescriptor(\CollectionEntry.mangaID)]
        )
    }
}

#Preview(
    "Blocked Collection changes",
    traits: .modifier(CollectionBlockedOutcomePreviewModifier<CollectionBlockedOutcomePreviewScenarios.List>())
) {
    NavigationStack {
        CollectionBlockedOutcomesView(
            authority: CollectionBlockedOutcomePreviewFixtures.authority,
            resolution: CollectionBlockedOutcomePreviewFixtures.resolution
        )
    }
}

#Preview(
    "No blocked Collection changes",
    traits: .modifier(CollectionBlockedOutcomePreviewModifier<CollectionBlockedOutcomePreviewScenarios.Empty>())
) {
    NavigationStack {
        CollectionBlockedOutcomesView(
            authority: CollectionBlockedOutcomePreviewFixtures.authority,
            resolution: CollectionBlockedOutcomePreviewFixtures.resolution
        )
    }
}
