//
//  CollectionReadOnlyBanner.swift
//  MangaLibrary
//

import SwiftUI

struct CollectionReadOnlyBanner: View {
    let restriction: CollectionAccess.MutationRestriction

    var body: some View {
        Label(restriction.bannerMessage, systemImage: "lock")
            .font(.footnote)
            .foregroundStyle(.onWarning)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal)
            .padding(.vertical, 10)
            .background(.warningFill, in: .rect)
            .accessibilityIdentifier("collection.read-only")
    }
}

private extension CollectionAccess.MutationRestriction {
    var bannerMessage: LocalizedStringResource {
        switch self {
        case .authenticationRequired:
            "Sign in again to change this collection. Saved items remain available offline."
        case .authenticating:
            "Collection changes are paused while authentication completes."
        case .signingOut:
            "Collection changes are paused while sign-out completes."
        }
    }
}

#Preview("Collection read-only banner") {
    CollectionReadOnlyBanner(restriction: .authenticationRequired)
}
