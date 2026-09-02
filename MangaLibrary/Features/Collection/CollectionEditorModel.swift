//
//  CollectionEditorModel.swift
//  MangaLibrary
//

import Foundation
import Observation

struct CollectionIdentity: Hashable {
    let userID: UUID
    let mangaID: Manga.ID
}

struct CollectionEditorSeed: Identifiable, Equatable {
    let identity: CollectionIdentity
    let authority: SessionAuthority
    let title: String?
    let mangaSnapshot: CollectionMangaSnapshot?
    let state: CollectionSnapshot
    let isExistingEntry: Bool

    var id: CollectionIdentity { identity }
}

enum CollectionEditorInputFailure: Equatable {
    case invalidOwnedVolume
    case pendingOwnedVolume
    case invalidReadingVolume
}

@Observable @MainActor
final class CollectionEditorModel {
    enum SubmissionState: Equatable {
        case idle
        case saving
        case deleting
        case failed(CollectionMutationError)
    }

    let seed: CollectionEditorSeed

    private(set) var ownedVolumes: Set<Int64>
    var readingVolumeText: String {
        didSet {
            if inputFailure == .invalidReadingVolume {
                inputFailure = nil
            }
        }
    }
    var volumeInput = "" {
        didSet {
            if inputFailure == .invalidOwnedVolume || inputFailure == .pendingOwnedVolume {
                inputFailure = nil
            }
        }
    }
    private(set) var inputFailure: CollectionEditorInputFailure?
    private(set) var submissionState: SubmissionState = .idle

    private let mutation: CollectionMutation

    init(seed: CollectionEditorSeed, mutation: CollectionMutation) {
        self.seed = seed
        self.mutation = mutation
        ownedVolumes = Set(seed.state.ownedVolumes)
        readingVolumeText = seed.state.readingVolume.map(String.init) ?? ""
    }

    var knownTotalVolumes: Int64? { seed.state.knownTotalVolumes }

    var isComplete: Bool {
        guard let knownTotalVolumes, knownTotalVolumes > 0 else { return false }

        return ownedVolumes == Set(1...knownTotalVolumes)
    }

    var isSubmitting: Bool {
        switch submissionState {
        case .saving, .deleting:
            true
        case .idle, .failed:
            false
        }
    }

    var canSave: Bool {
        isSubmitting == false
    }

    var sortedOwnedVolumes: [Int64] {
        ownedVolumes.sorted()
    }

    func owns(volume: Int64) -> Bool {
        ownedVolumes.contains(volume)
    }

    func setOwned(_ ownsVolume: Bool, volume: Int64) {
        inputFailure = nil
        if ownsVolume {
            ownedVolumes.insert(volume)
        } else {
            ownedVolumes.remove(volume)
        }
    }

    func addUnknownVolume() {
        let normalized = volumeInput.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let volume = Int64(normalized), volume > 0 else {
            inputFailure = .invalidOwnedVolume
            return
        }

        ownedVolumes.insert(volume)
        volumeInput = ""
        inputFailure = nil
    }

    func removeOwnedVolume(_ volume: Int64) {
        ownedVolumes.remove(volume)
        inputFailure = nil
    }

    func setComplete(_ complete: Bool) {
        guard let knownTotalVolumes, knownTotalVolumes > 0 else { return }

        ownedVolumes = complete ? Set(1...knownTotalVolumes) : []
    }

    func save() async -> Bool {
        guard hasPendingVolumeInput == false else {
            inputFailure = .pendingOwnedVolume
            return false
        }
        guard case let .valid(readingVolume) = parsedReadingVolume else {
            inputFailure = .invalidReadingVolume
            return false
        }

        submissionState = .saving
        inputFailure = nil
        do {
            _ = try await mutation(
                CollectionMutationCommand(
                    authority: seed.authority,
                    mangaID: seed.identity.mangaID,
                    mangaSnapshot: seed.mangaSnapshot,
                    knownTotalVolumes: knownTotalVolumes,
                    change: .replaceState(
                        ownedVolumes: sortedOwnedVolumes,
                        readingVolume: readingVolume,
                        isComplete: isComplete
                    )
                )
            )
            submissionState = .idle
            return true
        } catch let error {
            submissionState = .failed(error)
            return false
        }
    }

    func delete() async -> Bool {
        guard seed.isExistingEntry else { return false }

        submissionState = .deleting
        inputFailure = nil
        do {
            _ = try await mutation(
                CollectionMutationCommand(
                    authority: seed.authority,
                    mangaID: seed.identity.mangaID,
                    knownTotalVolumes: knownTotalVolumes,
                    change: .delete
                )
            )
            submissionState = .idle
            return true
        } catch let error {
            submissionState = .failed(error)
            return false
        }
    }

    private var parsedReadingVolume: ParsedReadingVolume {
        let normalized = readingVolumeText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard normalized.isEmpty == false else { return .valid(nil) }
        guard let volume = Int64(normalized), volume > 0 else { return .invalid }
        if let knownTotalVolumes, volume > knownTotalVolumes {
            return .invalid
        }

        return .valid(volume)
    }

    private var hasPendingVolumeInput: Bool {
        volumeInput.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false
    }
}

extension CollectionEditorSeed {
    static func catalog(
        authority: SessionAuthority,
        manga: Manga,
        existingState: CollectionSnapshot?
    ) -> CollectionEditorSeed {
        CollectionEditorSeed(
            identity: CollectionIdentity(userID: authority.userID, mangaID: manga.id),
            authority: authority,
            title: manga.title,
            mangaSnapshot: CollectionMangaSnapshot(manga: manga),
            state: resolvedState(manga: manga, existingState: existingState),
            isExistingEntry: existingState != nil
        )
    }

    private static func resolvedState(manga: Manga, existingState: CollectionSnapshot?) -> CollectionSnapshot {
        guard let existingState else {
            return CollectionSnapshot(
                ownedVolumes: [],
                readingVolume: nil,
                isComplete: false,
                knownTotalVolumes: manga.totalVolumes,
                isTombstone: false
            )
        }

        return CollectionSnapshot(
            ownedVolumes: existingState.ownedVolumes,
            readingVolume: existingState.readingVolume,
            isComplete: existingState.isComplete,
            knownTotalVolumes: resolvedKnownTotal(manga: manga, existingState: existingState),
            isTombstone: false
        )
    }

    private static func resolvedKnownTotal(manga: Manga, existingState: CollectionSnapshot) -> Int64? {
        guard let publishedTotal = manga.totalVolumes else { return existingState.knownTotalVolumes }
        guard existingState.isComplete == false else { return existingState.knownTotalVolumes }
        guard existingState.ownedVolumes.allSatisfy({ $0 <= publishedTotal }) else {
            return existingState.knownTotalVolumes
        }
        guard existingState.readingVolume.map({ $0 <= publishedTotal }) ?? true else {
            return existingState.knownTotalVolumes
        }

        return publishedTotal
    }
}

private enum ParsedReadingVolume {
    case valid(Int64?)
    case invalid
}

extension CollectionMutationError {
    var errorDescriptionResource: LocalizedStringResource {
        switch self {
        case .invalidIdentity:
            "This manga cannot be identified."
        case let .nonPositiveKnownTotal(total):
            "The published total \(total) is invalid."
        case let .nonPositiveVolume(volume):
            "Volume \(volume) must be positive."
        case let .volumeExceedsKnownTotal(volume, total):
            "Volume \(volume) exceeds the published total of \(total)."
        case .completeRequiresKnownTotal:
            "A published total is required before marking the collection complete."
        case let .knownTotalInvalidatesCurrentState(total):
            "The published total of \(total) conflicts with the saved collection."
        case .mangaSnapshotRequired:
            "Offline manga details are required before adding this item."
        case .mangaSnapshotIdentityMismatch:
            "The manga details no longer match this collection item."
        case .collectionEntryNotFound:
            "This collection item no longer exists."
        case .authenticationRequired:
            "Sign in again to change your collection."
        case .sequenceExhausted, .persistenceConflict:
            "The collection could not be saved. Your previous state is unchanged."
        case .cancelled:
            "The collection change was cancelled."
        }
    }
}
