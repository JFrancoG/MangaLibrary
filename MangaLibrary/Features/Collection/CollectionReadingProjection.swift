//
//  CollectionReadingProjection.swift
//  MangaLibrary
//

import Foundation
import SwiftData

/// All eligible persisted readings, ordered for subsequent Deluxe preparation.
///
/// This app-only value carries the exact authority and optional remote cover inputs;
/// it is neither a wire payload nor permission to publish after that authority changes.
/// Resource admission, byte-budget truncation and publication belong to later steps.
struct CollectionReadingProjection: Equatable {
    struct Item: Equatable {
        let mangaID: Manga.ID
        let title: String?
        let readingVolume: Int
        let totalVolumes: Int?
        let coverURL: URL?
    }

    let authority: SessionAuthority
    let items: [Item]

    var totalEligibleCount: Int64 { Int64(items.count) }
}

enum CollectionReadingProjectionError: Error, Equatable {
    case authenticationRequired
    case cancelled
    case incompatibleStoredReading
    case incompatibleSnapshotIdentity
    case uncommittedChanges
    case persistenceUnavailable
}

extension CollectionMutationActor {
    /// Reads one authorized, committed Collection state without mutating it.
    ///
    /// Selection ignores ownership and completeness. Invalid selected reading/total
    /// data or a mismatched presentation identity fails the whole preparation;
    /// callers must not reinterpret that error as an empty collection or publish it.
    /// Titles are abbreviated on complete Characters and sorted with a fixed locale.
    /// Authorization is checked around the fetch and again after sorting; the returned
    /// authority must still be revalidated at the eventual publication boundary.
    /// Cancellation and persistence errors return no partial projection. An unsaved
    /// context is rejected without saving or rolling back someone else's work.
    func readingProjection(
        authorization: SessionCommitAuthorization
    ) throws(CollectionReadingProjectionError) -> CollectionReadingProjection {
        do {
            let items = try authorization.perform {
                try Task.checkCancellation()
                guard modelContext.hasChanges == false else {
                    throw CollectionReadingProjectionError.uncommittedChanges
                }
                var descriptor = FetchDescriptor<CollectionEntry>(
                    predicate: CollectionEntry.activePredicate(userID: authorization.authority.userID)
                )
                descriptor.includePendingChanges = false
                return try modelContext.fetch(descriptor).compactMap { entry in
                    try Task.checkCancellation()
                    return try readingItem(from: entry)
                }
            }
            let keyedItems = items.map { item in
                let key = item.title.map {
                    Array(
                        $0.precomposedStringWithCanonicalMapping
                            .folding(
                                options: [.caseInsensitive, .diacriticInsensitive, .widthInsensitive],
                                locale: Locale(identifier: "en_US_POSIX")
                            )
                            .precomposedStringWithCanonicalMapping.utf8
                    )
                }
                return (item: item, key: key)
            }
            let ordered = keyedItems.sorted { lhs, rhs in
                switch (lhs.key, rhs.key) {
                case let (left?, right?) where left != right:
                    return left.lexicographicallyPrecedes(right)
                case (_?, nil):
                    return true
                case (nil, _?):
                    return false
                default:
                    return lhs.item.mangaID < rhs.item.mangaID
                }
            }.map(\.item)
            try Task.checkCancellation()
            return try authorization.perform {
                CollectionReadingProjection(authority: authorization.authority, items: ordered)
            }
        } catch let error as CollectionReadingProjectionError {
            throw error
        } catch is SessionCommitAuthorizationError {
            throw .authenticationRequired
        } catch is CancellationError {
            throw .cancelled
        } catch {
            throw .persistenceUnavailable
        }
    }

    private func readingItem(from entry: CollectionEntry) throws -> CollectionReadingProjection.Item? {
        guard let reading = entry.readingVolume else { return nil }
        guard CollectionVolumePolicy.contains(reading) else {
            throw CollectionReadingProjectionError.incompatibleStoredReading
        }
        if let total = entry.knownTotalVolumes {
            guard CollectionVolumePolicy.contains(total), reading <= total else {
                throw CollectionReadingProjectionError.incompatibleStoredReading
            }
        }
        if let snapshot = entry.mangaSnapshot, snapshot.mangaID != entry.mangaID {
            throw CollectionReadingProjectionError.incompatibleSnapshotIdentity
        }
        return CollectionReadingProjection.Item(
            mangaID: entry.mangaID,
            title: preparedReadingTitle(entry.mangaSnapshot?.title),
            readingVolume: Int(reading),
            totalVolumes: entry.knownTotalVolumes.map(Int.init),
            coverURL: entry.mangaSnapshot?.coverURL
        )
    }

    private func preparedReadingTitle(_ source: String?) -> String? {
        guard let title = source?.trimmingCharacters(in: .whitespacesAndNewlines), !title.isEmpty else { return nil }
        guard title.utf8.count > 512 else { return title }

        var prefix = ""
        var byteCount = 3
        for character in title {
            let characterBytes = String(character).utf8.count
            guard byteCount + characterBytes <= 512 else { break }
            prefix.append(character)
            byteCount += characterBytes
        }
        return prefix + "…"
    }
}
