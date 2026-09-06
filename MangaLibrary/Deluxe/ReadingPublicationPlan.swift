import Foundation

/// Resolves the transportable prefix without reserving revisions or admitting cover files.
///
/// Every candidate is validated before truncation. Only prepared cover identifiers participate;
/// private source URLs are never serialized. Budget probes use the final codec with the widest
/// revision, canonical UUIDs and the wire's fixed date length, so later counters cannot shrink it.
/// Cancellation or invalid candidates fail the whole preparation instead of producing empty content.
struct ReadingPublicationPlan {
    let authority: SessionAuthority
    let items: [ReadingSnapshot.Item]
    let totalEligibleCount: Int64

    init(projection: CollectionReadingProjection, coverResourceIDs: [Manga.ID: String] = [:]) throws {
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
        authority = projection.authority
        totalEligibleCount = projection.totalEligibleCount
        guard !candidates.isEmpty else {
            items = []
            return
        }

        if try !Self.fits(candidates.prefix(1), projection: projection) {
            let first = candidates[0]
            candidates[0] = try ReadingSnapshot.Item(
                mangaID: first.mangaID,
                title: first.title,
                readingVolume: first.readingVolume,
                totalVolumes: first.totalVolumes,
                coverResourceID: nil
            )
            guard try Self.fits(candidates.prefix(1), projection: projection) else {
                throw ReadingPublicationError.contextTooLarge
            }
        }

        // Grow only to the first oversized probe, avoiding an envelope of the entire collection.
        var lower = 1
        var upper = 1
        while upper < candidates.count {
            try Task.checkCancellation()
            upper += min(upper, candidates.count - upper)
            guard try Self.fits(candidates.prefix(upper), projection: projection) else { break }
            lower = upper
        }
        while lower + 1 < upper {
            try Task.checkCancellation()
            let middle = lower + (upper - lower) / 2
            if try Self.fits(candidates.prefix(middle), projection: projection) {
                lower = middle
            } else {
                upper = middle
            }
        }
        try Task.checkCancellation()
        items = Array(candidates.prefix(lower))
    }

    private static func fits(
        _ items: ArraySlice<ReadingSnapshot.Item>,
        projection: CollectionReadingProjection
    ) throws -> Bool {
        let budget = try ReadingSnapshot(
            publicationGeneration: projection.authority.generation,
            revision: .max,
            sessionGeneration: projection.authority.generation,
            state: .content,
            generatedAt: Date(timeIntervalSince1970: 0),
            totalEligibleCount: projection.totalEligibleCount,
            items: Array(items)
        )
        do {
            let data = try ReadingSnapshotCodec.encode(budget)
            return try ReadingSnapshotCodec.contextByteCount(for: data) <= ReadingSnapshotCodec.maximumByteCount
        } catch ReadingSnapshotError.payloadTooLarge {
            return false
        }
    }
}
