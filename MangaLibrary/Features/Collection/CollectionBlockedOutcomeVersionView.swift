//
//  CollectionBlockedOutcomeVersionView.swift
//  MangaLibrary
//

import SwiftUI

struct CollectionBlockedOutcomeVersionView: View {
    enum Version: Equatable {
        case absent
        case state(CollectionSnapshot)
    }

    let version: Version

    var body: some View {
        switch version {
        case .absent:
            Label("Not in collection", systemImage: "minus.circle")
                .foregroundStyle(.textSecondary)
                .accessibilityIdentifier("collection.blocked-outcome.version.absent")

        case let .state(state) where state.isTombstone:
            Label("Removed from collection", systemImage: "trash")
                .foregroundStyle(.textSecondary)
                .accessibilityIdentifier("collection.blocked-outcome.version.removed")

        case let .state(state):
            CollectionStateSummary(state: state, showsKnownTotalVolumes: true)
                .accessibilityIdentifier("collection.blocked-outcome.version.present")
        }
    }
}

#Preview(
    "Present Collection version",
    traits: .modifier(CollectionBlockedOutcomePreviewModifier<CollectionBlockedOutcomePreviewScenarios.Empty>())
) {
    CollectionBlockedOutcomeVersionView(version: .state(CollectionBlockedOutcomePreviewFixtures.deviceState))
        .padding()
}

#Preview(
    "Absent Collection version",
    traits: .modifier(CollectionBlockedOutcomePreviewModifier<CollectionBlockedOutcomePreviewScenarios.Empty>())
) {
    CollectionBlockedOutcomeVersionView(version: .absent)
        .padding()
}

#Preview(
    "Collection version with unknown total",
    traits: .modifier(CollectionBlockedOutcomePreviewModifier<CollectionBlockedOutcomePreviewScenarios.Empty>())
) {
    CollectionBlockedOutcomeVersionView(
        version: .state(
            CollectionSnapshot(
                ownedVolumes: [1, 3],
                readingVolume: 2,
                isComplete: false,
                knownTotalVolumes: nil,
                isTombstone: false
            )
        )
    )
    .padding()
}
