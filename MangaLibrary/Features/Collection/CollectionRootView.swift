//
//  CollectionRootView.swift
//  MangaLibrary
//

import SwiftData
import SwiftUI

struct CollectionRootView: View {
    let access: CollectionAccess
    let mutation: CollectionMutation

    var body: some View {
        switch access {
        case let .unavailable(reason):
            NavigationStack {
                ContentUnavailableView(
                    reason.title,
                    systemImage: reason.systemImage,
                    description: Text(reason.description)
                )
                .navigationTitle("Collection")
                .accessibilityIdentifier("collection.unavailable")
            }
        case let .user(userID, restriction):
            CollectionUserRootView(userID: userID, restriction: restriction, mutation: mutation)
                .id(userID)
        }
    }
}

private extension CollectionAccess.UnavailableReason {
    var title: LocalizedStringResource {
        switch self {
        case .restoring:
            "Restoring account"
        case .restorationFailed:
            "Collection unavailable"
        case .signedOut:
            "Sign in to view your collection"
        case .authenticating:
            "Signing in"
        }
    }

    var description: LocalizedStringResource {
        switch self {
        case .restoring:
            "Your collection appears after the active account is restored."
        case .restorationFailed:
            "Retry account restoration before opening private collection data."
        case .signedOut:
            "Collection data belongs to an authenticated account and is never anonymous."
        case .authenticating:
            "Your collection appears after authentication completes."
        }
    }

    var systemImage: String {
        switch self {
        case .restoring, .authenticating:
            "person.crop.circle.badge.clock"
        case .restorationFailed:
            "exclamationmark.triangle"
        case .signedOut:
            "person.crop.circle.badge.questionmark"
        }
    }
}

#Preview("Collection content", traits: .modifier(CollectionPreviewModifier<CollectionPreviewScenarios.Content>())) {
    @Previewable @Environment(\.modelContext) var modelContext
    CollectionPreviewSupport.content(container: modelContext.container)
}

#Preview("Collection empty", traits: .modifier(CollectionPreviewModifier<CollectionPreviewScenarios.Empty>())) {
    @Previewable @Environment(\.modelContext) var modelContext
    CollectionPreviewSupport.empty(container: modelContext.container)
}

#Preview("Collection read only", traits: .modifier(CollectionPreviewModifier<CollectionPreviewScenarios.ReadOnly>())) {
    @Previewable @Environment(\.modelContext) var modelContext
    CollectionPreviewSupport.readOnly(container: modelContext.container)
}

#Preview(
    "Collection signed out",
    traits: .modifier(CollectionPreviewModifier<CollectionPreviewScenarios.SignedOut>())
) {
    @Previewable @Environment(\.modelContext) var modelContext
    CollectionPreviewSupport.signedOut(container: modelContext.container)
}

#Preview("Collection restoring", traits: .modifier(CollectionPreviewModifier<CollectionPreviewScenarios.Restoring>())) {
    @Previewable @Environment(\.modelContext) var modelContext
    CollectionPreviewSupport.restoring(container: modelContext.container)
}

#Preview(
    "Collection restoration failed",
    traits: .modifier(CollectionPreviewModifier<CollectionPreviewScenarios.RestorationFailed>())
) {
    @Previewable @Environment(\.modelContext) var modelContext
    CollectionPreviewSupport.restorationFailed(container: modelContext.container)
}
