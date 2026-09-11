import Foundation

/// Resolves the transportable selection without reserving revisions or admitting cover files.
///
/// Every reading candidate is validated before truncation. Only prepared cover identifiers participate;
/// private source URLs are never serialized. Budget probes use the final codec with the widest
/// revision, canonical UUIDs and the wire's fixed date length, so later counters cannot shrink it.
/// A preferred reading replaces the prefix tail when necessary, retaining canonical order;
/// its optional metadata participates in the final byte budget.
/// Cancellation or invalid readings fail preparation. The local collection is complete or unavailable;
/// invalid data and text exceeding its bounds never become a partial collection. Optional cover
/// references are reduced first, and its descriptor participates in the reading envelope budget.
struct ReadingPublicationPlan {
    private let storedAuthority: SessionAuthority
    private let storedItems: [ReadingSnapshot.Item]
    private let storedTotalEligibleCount: Int64
    let collection: CollectionWidgetSnapshot?
    let collectionData: Data?

    var authority: SessionAuthority { storedAuthority }
    var items: [ReadingSnapshot.Item] { storedItems }
    var totalEligibleCount: Int64 { storedTotalEligibleCount }
}

extension ReadingPublicationPlan {
    init(
        projection: CollectionReadingProjection,
        coverResourceIDs: [Manga.ID: String] = [:],
        preferredStartMangaID: Manga.ID? = nil,
        preferredCollectionStartMangaID: Manga.ID? = nil
    ) throws {
        try Task.checkCancellation()
        var identities = Set<Manga.ID>()
        var candidates = try projection.items.map { item in
            try Task.checkCancellation()
            guard identities.insert(item.mangaID).inserted else { throw ReadingSnapshotError.duplicateMangaID }
            return try ReadingSnapshot.Item(
                mangaID: item.mangaID,
                title: item.title,
                readingVolume: item.readingVolume,
                totalVolumes: item.totalVolumes,
                coverResourceID: coverResourceIDs[item.mangaID]
            )
        }
        storedAuthority = projection.authority
        storedTotalEligibleCount = projection.totalEligibleCount
        let preparedCollection = try Self.prepareCollection(
            projection.collectionItems,
            coverResourceIDs: coverResourceIDs,
            preferredStartMangaID: preferredCollectionStartMangaID
        )
        collection = preparedCollection?.snapshot
        collectionData = preparedCollection?.data
        let reference = try preparedCollection.map { _ in
            try CollectionWidgetSnapshot.Reference(
                slot: 1,
                digest: String(repeating: "0", count: 64),
                byteCount: CollectionWidgetSnapshotCodec.maximumByteCount
            )
        }
        guard !candidates.isEmpty else {
            storedItems = []
            return
        }

        if try !Self.fits(candidates.prefix(1), projection: projection, collectionReference: reference) {
            let first = candidates[0]
            candidates[0] = try ReadingSnapshot.Item(
                mangaID: first.mangaID,
                title: first.title,
                readingVolume: first.readingVolume,
                totalVolumes: first.totalVolumes,
                coverResourceID: nil
            )
            guard try Self.fits(candidates.prefix(1), projection: projection, collectionReference: reference) else {
                throw ReadingPublicationError.contextTooLarge
            }
        }

        // Grow only to the first oversized probe, avoiding an envelope of the entire collection.
        var lower = 1
        var upper = 1
        while upper < candidates.count {
            try Task.checkCancellation()
            upper += min(upper, candidates.count - upper)
            guard try Self.fits(candidates.prefix(upper), projection: projection, collectionReference: reference) else {
                break
            }
            lower = upper
        }
        while lower + 1 < upper {
            try Task.checkCancellation()
            let middle = lower + (upper - lower) / 2
            if try Self.fits(candidates.prefix(middle), projection: projection, collectionReference: reference) {
                lower = middle
            } else {
                upper = middle
            }
        }
        try Task.checkCancellation()
        var selected = Array(candidates.prefix(lower))
        if let preferred = candidates.first(where: { $0.mangaID == preferredStartMangaID }) {
            if !selected.contains(where: { $0.mangaID == preferred.mangaID }) {
                selected.removeLast()
                selected.append(preferred)
            }
            while try !Self.fits(
                selected[...],
                projection: projection,
                preferredStartMangaID: preferred.mangaID,
                collectionReference: reference
            ) {
                try Task.checkCancellation()
                if selected.count > 1 {
                    let tail = selected.count - 1
                    selected.remove(at: selected[tail].mangaID == preferred.mangaID ? tail - 1 : tail)
                } else if selected[0].coverResourceID != nil {
                    selected[0] = try ReadingSnapshot.Item(
                        mangaID: preferred.mangaID,
                        title: preferred.title,
                        readingVolume: preferred.readingVolume,
                        totalVolumes: preferred.totalVolumes,
                        coverResourceID: nil
                    )
                } else {
                    throw ReadingPublicationError.contextTooLarge
                }
            }
        }
        storedItems = selected
    }

    private static func prepareCollection(
        _ candidates: [CollectionReadingProjection.CollectionItem]?,
        coverResourceIDs: [Manga.ID: String],
        preferredStartMangaID: Manga.ID?
    ) throws -> (snapshot: CollectionWidgetSnapshot, data: Data)? {
        guard let candidates, candidates.count <= CollectionWidgetSnapshotCodec.maximumItemCount else { return nil }
        try Task.checkCancellation()
        let items: [CollectionWidgetSnapshot.Item]
        do {
            items = try candidates.map { item in
                try CollectionWidgetSnapshot.Item(
                    mangaID: item.mangaID,
                    title: item.title,
                    ownedVolumeCount: item.ownedVolumeCount,
                    totalVolumes: item.totalVolumes,
                    isComplete: item.isComplete,
                    coverResourceID: nil
                )
            }
        } catch {
            return nil
        }
        try Task.checkCancellation()
        let baseline: CollectionWidgetSnapshot
        let baselineData: Data
        let preferred = items.contains(where: { $0.mangaID == preferredStartMangaID }) ? preferredStartMangaID : nil
        do {
            baseline = try CollectionWidgetSnapshot(items: items, preferredStartMangaID: preferred)
            baselineData = try CollectionWidgetSnapshotCodec.encode(baseline)
        } catch {
            return nil
        }
        try Task.checkCancellation()
        var coveredIDs = items.compactMap { item in
            coverResourceIDs[item.mangaID].map { _ in item.mangaID }
        }
        if let index = coveredIDs.firstIndex(where: { $0 == preferred }) {
            coveredIDs.insert(coveredIDs.remove(at: index), at: 0)
        }
        var accepted = (snapshot: baseline, data: baselineData)
        var lower = 0
        var upper = coveredIDs.count + 1
        while lower + 1 < upper {
            try Task.checkCancellation()
            let count = lower + (upper - lower) / 2
            let selected = Set(coveredIDs.prefix(count))
            let proposed = try CollectionWidgetSnapshot(
                items: items.map { item in
                    try CollectionWidgetSnapshot.Item(
                        mangaID: item.mangaID,
                        title: item.title,
                        ownedVolumeCount: item.ownedVolumeCount,
                        totalVolumes: item.totalVolumes,
                        isComplete: item.isComplete,
                        coverResourceID: selected.contains(item.mangaID) ? coverResourceIDs[item.mangaID] : nil
                    )
                },
                preferredStartMangaID: preferred
            )
            do {
                let data = try CollectionWidgetSnapshotCodec.encode(proposed)
                accepted = (snapshot: proposed, data: data)
                lower = count
            } catch {
                upper = count
            }
        }
        try Task.checkCancellation()
        return accepted
    }

    private static func fits(
        _ items: ArraySlice<ReadingSnapshot.Item>,
        projection: CollectionReadingProjection,
        preferredStartMangaID: Manga.ID? = nil,
        collectionReference: CollectionWidgetSnapshot.Reference? = nil
    ) throws -> Bool {
        let budget = try ReadingSnapshot(
            publicationGeneration: projection.authority.generation,
            revision: .max,
            sessionGeneration: projection.authority.generation,
            state: .content,
            generatedAt: Date(timeIntervalSince1970: 0),
            totalEligibleCount: projection.totalEligibleCount,
            items: Array(items),
            preferredStartMangaID: preferredStartMangaID,
            collectionReference: collectionReference
        )
        do {
            let data = try ReadingSnapshotCodec.encode(budget)
            return try ReadingSnapshotCodec.contextByteCount(for: data) <= ReadingSnapshotCodec.maximumByteCount
        } catch ReadingSnapshotError.payloadTooLarge {
            return false
        }
    }
}
