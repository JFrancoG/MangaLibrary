//
//  CollectionControlsView.swift
//  MangaLibrary
//

import SwiftData
import SwiftUI

struct CollectionControlsView: View {
    @Query private var entries: [CollectionEntry]

    @State private var editorSeed: CollectionEditorSeed?
    @State private var isExpanded = true

    let manga: Manga
    let access: CollectionAccess
    let mutation: CollectionMutation

    var body: some View {
        DisclosureGroup(isExpanded: $isExpanded) {
            VStack(alignment: .leading, spacing: 12) {
                switch access {
                case let .unavailable(reason):
                    Text(reason.collectionMessage)
                        .foregroundStyle(.textSecondary)
                        .multilineTextAlignment(.center)
                        .frame(maxWidth: .infinity)
                        .accessibilityIdentifier("collection.controls.unavailable")
                case let .user(userID, restriction):
                    collectionContent(userID: userID, restriction: restriction)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.top, 8)
        } label: {
            Text("My Collection")
                .font(.headline)
                .foregroundStyle(.textPrimary)
                .frame(minHeight: 44, alignment: .leading)
                .contentShape(.rect)
                .accessibilityHeading(.h2)
                .accessibilityIdentifier("collection.disclosure.\(manga.id)")
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .background(.surface, in: .rect(cornerRadius: 16))
        .sheet(item: $editorSeed) { seed in
            CollectionEditorView(seed: seed, mutation: mutation)
        }
        .onChange(of: access) { previousAccess, currentAccess in
            let identityChanged = previousAccess.userID != currentAccess.userID
            if identityChanged || currentAccess.canMutate == false {
                editorSeed = nil
            }
        }
    }

    @ViewBuilder
    private func collectionContent(userID: UUID, restriction: CollectionAccess.MutationRestriction?) -> some View {
        if let entry {
            CollectionStateSummary(state: entry.state)

            if let restriction {
                readOnlyNotice(restriction)
            } else {
                Button("Edit Collection") {
                    editorSeed = seed(userID: userID, entry: entry)
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
                .frame(maxWidth: .infinity)
                .accessibilityIdentifier("collection.edit.\(manga.id)")
            }
        } else {
            Text("This manga is not in your collection.")
                .foregroundStyle(.textSecondary)
                .multilineTextAlignment(.center)
                .frame(maxWidth: .infinity)

            if let restriction {
                readOnlyNotice(restriction)
            } else {
                Button("Add to Collection") {
                    editorSeed = seed(userID: userID, entry: nil)
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
                .frame(maxWidth: .infinity)
                .accessibilityIdentifier("collection.add.\(manga.id)")
            }
        }
    }

    private func readOnlyNotice(_ restriction: CollectionAccess.MutationRestriction) -> some View {
        Text(restriction.message)
            .font(.footnote)
            .foregroundStyle(.textSecondary)
            .multilineTextAlignment(.center)
            .frame(maxWidth: .infinity)
            .accessibilityIdentifier("collection.read-only")
    }

    private var entry: CollectionEntry? {
        entries.first
    }

    private func seed(userID: UUID, entry: CollectionEntry?) -> CollectionEditorSeed {
        CollectionEditorSeed.catalog(userID: userID, manga: manga, existingState: entry?.state)
    }
}

extension CollectionControlsView {
    init(manga: Manga, access: CollectionAccess, mutation: CollectionMutation) {
        self.manga = manga
        self.access = access
        self.mutation = mutation

        if let userID = access.userID {
            _entries = Query(filter: CollectionEntry.activePredicate(userID: userID, mangaID: manga.id))
        } else {
            _entries = Query(filter: #Predicate<CollectionEntry> { _ in false })
        }
    }
}

private extension CollectionAccess.UnavailableReason {
    var collectionMessage: LocalizedStringResource {
        switch self {
        case .restoring:
            "Your account is being restored."
        case .restorationFailed:
            "Restore your account before viewing its collection."
        case .signedOut:
            "Sign in to add this manga to your collection."
        case .authenticating:
            "Your account is being authenticated."
        }
    }
}

private extension CollectionAccess.MutationRestriction {
    var message: LocalizedStringResource {
        switch self {
        case .authenticationRequired:
            "Sign in again to change your collection."
        case .authenticating:
            "Collection changes are paused while you sign in."
        case .signingOut:
            "Collection changes are paused while you sign out."
        }
    }
}

#Preview("Collection controls", traits: .modifier(CollectionPreviewModifier<CollectionPreviewScenarios.Controls>())) {
    @Previewable @Environment(\.modelContext) var modelContext
    CollectionPreviewSupport.controls(container: modelContext.container)
}

#Preview(
    "Collection controls empty",
    traits: .modifier(CollectionPreviewModifier<CollectionPreviewScenarios.ControlsEmpty>())
) {
    @Previewable @Environment(\.modelContext) var modelContext
    CollectionPreviewSupport.controls(container: modelContext.container)
}

#Preview(
    "Collection controls signed out",
    traits: .modifier(CollectionPreviewModifier<CollectionPreviewScenarios.ControlsSignedOut>())
) {
    @Previewable @Environment(\.modelContext) var modelContext
    CollectionPreviewSupport.signedOutControls(container: modelContext.container)
}

#Preview(
    "Collection controls read only",
    traits: .modifier(CollectionPreviewModifier<CollectionPreviewScenarios.ControlsReadOnly>())
) {
    @Previewable @Environment(\.modelContext) var modelContext
    CollectionPreviewSupport.readOnlyControls(container: modelContext.container)
}
