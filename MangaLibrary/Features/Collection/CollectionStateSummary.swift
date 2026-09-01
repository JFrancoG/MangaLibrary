//
//  CollectionStateSummary.swift
//  MangaLibrary
//

import Foundation
import SwiftUI

struct CollectionStateSummary: View {
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @Environment(\.locale) private var locale

    let state: CollectionSnapshot

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            stateRow("Owned") {
                Text(ownedVolumesDescription)
            }

            stateRow("Reading") {
                if let readingVolume = state.readingVolume {
                    Text("Volume \(readingVolume)")
                } else {
                    Text("Not set")
                }
            }

            stateRow("Complete") {
                Text(state.isComplete ? "Yes" : "No")
            }
        }
        .foregroundStyle(.textPrimary)
        .accessibilityElement(children: .contain)
    }

    @ViewBuilder
    private func stateRow(
        _ title: LocalizedStringKey,
        @ViewBuilder value: () -> some View
    ) -> some View {
        if dynamicTypeSize.isAccessibilitySize {
            stackedStateRow(title, value: value)
        } else {
            ViewThatFits(in: .horizontal) {
                LabeledContent(title) {
                    value()
                        .fixedSize(horizontal: true, vertical: false)
                }

                stackedStateRow(title, value: value)
            }
        }
    }

    private func stackedStateRow(
        _ title: LocalizedStringKey,
        @ViewBuilder value: () -> some View
    ) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(title)
                .font(.headline)
            value()
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .accessibilityElement(children: .combine)
    }

    private var ownedVolumesDescription: String {
        guard state.ownedVolumes.isEmpty == false else { return String(localized: "None", locale: locale) }

        return state.ownedVolumes
            .map(String.init)
            .formatted(.list(type: .and).locale(locale))
    }
}

#Preview(
    "Collection state summary",
    traits: .modifier(CollectionPreviewModifier<CollectionPreviewScenarios.Controls>())
) {
    CollectionStateSummary(
        state: CollectionSnapshot(
            ownedVolumes: [1, 3],
            readingVolume: 2,
            isComplete: false,
            knownTotalVolumes: 27,
            isTombstone: false
        )
    )
    .padding()
}

#Preview(
    "Many owned volumes",
    traits: .modifier(CollectionPreviewModifier<CollectionPreviewScenarios.Controls>())
) {
    CollectionStateSummary(
        state: CollectionSnapshot(
            ownedVolumes: [9, 14, 19, 31, 33, 37, 41, 52, 54, 63, 65, 67, 68, 69, 71],
            readingVolume: nil,
            isComplete: false,
            knownTotalVolumes: 72,
            isTombstone: false
        )
    )
    .padding()
}
