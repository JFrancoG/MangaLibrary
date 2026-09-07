//
//  CollectionReadingProjection.swift
//  MangaLibrary
//

import Foundation
import SwiftData

/// Ordered persisted readings and an optional complete active collection for Deluxe preparation.
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

    struct CollectionItem: Equatable {
        let mangaID: Manga.ID
        let title: String?
        let ownedVolumeCount: Int
        let totalVolumes: Int?
        let isComplete: Bool
        let coverURL: URL?
    }

    let authority: SessionAuthority
    let items: [Item]
    private(set) var collectionItems: [CollectionItem]? = nil

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
    /// Reading selection ignores ownership and completeness. Invalid selected reading/total
    /// data or a mismatched presentation identity fails the whole preparation;
    /// callers must not reinterpret that error as an empty collection or publish it.
    /// Titles are abbreviated on complete Characters and sorted with a fixed locale.
    /// Authorization is checked around the fetch and again after sorting; the returned
    /// authority must still be revalidated at the eventual publication boundary.
    /// Cancellation and persistence errors return no partial projection. An unsaved
    /// context is rejected without saving or rolling back someone else's work. The same fetch
    /// also projects every active collection entry. Invalid ownership or an excessive item count
    /// makes only that optional projection unavailable; it never becomes a truncated collection.
    func readingProjection(
        authorization: SessionCommitAuthorization
    ) throws(CollectionReadingProjectionError) -> CollectionReadingProjection {
        do {
            let projected = try authorization.perform {
                try Task.checkCancellation()
                guard modelContext.hasChanges == false else {
                    throw CollectionReadingProjectionError.uncommittedChanges
                }
                var descriptor = FetchDescriptor<CollectionEntry>(
                    predicate: CollectionEntry.activePredicate(userID: authorization.authority.userID)
                )
                descriptor.includePendingChanges = false
                let entries = try modelContext.fetch(descriptor)
                var readings: [CollectionReadingProjection.Item] = []
                let fitsCollection = entries.count <= CollectionWidgetSnapshotCodec.maximumItemCount
                var collection: [CollectionReadingProjection.CollectionItem]? = fitsCollection ? [] : nil
                for entry in entries {
                    try Task.checkCancellation()
                    if let item = try readingItem(from: entry) {
                        readings.append(item)
                    }
                    if collection != nil {
                        if let item = collectionItem(from: entry) {
                            collection?.append(item)
                        } else {
                            collection = nil
                        }
                    }
                }
                return (readings: readings, collection: collection)
            }
            let ordered = orderedProjectionItems(projected.readings, title: \.title, identity: \.mangaID)
            let collection = projected.collection.map {
                orderedProjectionItems($0, title: \.title, identity: \.mangaID)
            }
            try Task.checkCancellation()
            return try authorization.perform {
                CollectionReadingProjection(
                    authority: authorization.authority,
                    items: ordered,
                    collectionItems: collection
                )
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

    private func collectionItem(from entry: CollectionEntry) -> CollectionReadingProjection.CollectionItem? {
        guard entry.mangaID > 0, CollectionVolumePolicy.isValid(entry.state) else { return nil }
        if let snapshot = entry.mangaSnapshot, snapshot.mangaID != entry.mangaID {
            return nil
        }
        return CollectionReadingProjection.CollectionItem(
            mangaID: entry.mangaID,
            title: preparedReadingTitle(entry.mangaSnapshot?.title),
            ownedVolumeCount: entry.ownedVolumes.count,
            totalVolumes: entry.knownTotalVolumes.map(Int.init),
            isComplete: entry.isComplete,
            coverURL: entry.mangaSnapshot?.coverURL
        )
    }

    private func orderedProjectionItems<Item>(
        _ items: [Item],
        title: KeyPath<Item, String?>,
        identity: KeyPath<Item, Manga.ID>
    ) -> [Item] {
        let keyed = items.map { item in
            let key = item[keyPath: title].map {
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
        return keyed.sorted { lhs, rhs in
            switch (lhs.key, rhs.key) {
            case let (left?, right?) where left != right:
                return left.lexicographicallyPrecedes(right)
            case (_?, nil):
                return true
            case (nil, _?):
                return false
            default:
                return lhs.item[keyPath: identity] < rhs.item[keyPath: identity]
            }
        }.map(\.item)
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
