import Foundation

/// Prepares optional images for transportable readings and bounded complete-collection candidates.
///
/// Input is fetched sequentially outside the caller's actor. Supply bounded bytes, such as
/// `ReadingCoverSource.data(from:)`; source buffers are not cached. Repeated URLs, including
/// failures, are resolved once and identical JPEGs share one retained value within eight MiB.
/// The supplied cache can reuse transformations between batches within its separate two-MiB limit;
/// each distinct URL still loads its current source before that lookup.
/// Collection contributes at most 128 additional distinct URLs, prioritizing its local-addition focus. Its text
/// remains complete even when images are omitted. Failed sources are placeholders, cancellation
/// aborts the batch, and no resource is admitted here. Publication still selects its final items
/// and rechecks authority before writing durable resources.
enum ReadingCoverBatch {
    @concurrent
    static func prepare(
        projection: CollectionReadingProjection,
        preferredStartMangaID: Manga.ID? = nil,
        preferredCollectionStartMangaID: Manga.ID? = nil,
        cache: ReadingCoverCache = ReadingCoverCache(),
        loadSource: @Sendable (URL) async throws -> Data?
    ) async throws -> [Manga.ID: ReadingCoverResource] {
        let plan = try ReadingPublicationPlan(
            projection: projection,
            preferredStartMangaID: preferredStartMangaID,
            preferredCollectionStartMangaID: preferredCollectionStartMangaID
        )
        let selected = Set(plan.items.map(\.mangaID))
        var candidates = projection.items.compactMap { item -> (mangaID: Manga.ID, url: URL)? in
            guard selected.contains(item.mangaID), let url = item.coverURL else { return nil }
            return (item.mangaID, url)
        }
        var knownURLs = Set(candidates.map(\.url))
        var extraURLs = 0
        if plan.collection != nil {
            var collectionItems = projection.collectionItems ?? []
            if let index = collectionItems.firstIndex(where: { $0.mangaID == preferredCollectionStartMangaID }) {
                collectionItems.insert(collectionItems.remove(at: index), at: 0)
            }
            for item in collectionItems where !selected.contains(item.mangaID) {
                try Task.checkCancellation()
                guard let url = item.coverURL else { continue }
                if !knownURLs.contains(url) {
                    guard extraURLs < 128 else { continue }
                    knownURLs.insert(url)
                    extraURLs += 1
                }
                candidates.append((item.mangaID, url))
            }
        }
        var resolutions: [URL: Resolution] = [:]
        var retained: [String: ReadingCoverResource] = [:]
        var retainedBytes = 0
        var covers: [Manga.ID: ReadingCoverResource] = [:]
        for item in candidates {
            try Task.checkCancellation()
            let url = item.url
            if let resolution = resolutions[url] {
                if case let .resource(identifier) = resolution {
                    covers[item.mangaID] = retained[identifier]
                }
                continue
            }
            resolutions[url] = .unavailable
            let prepared: ReadingCoverResource?
            do {
                guard let source = try await loadSource(url) else {
                    try Task.checkCancellation()
                    continue
                }
                prepared = try await cache.prepare(source)
            } catch is CancellationError {
                throw CancellationError()
            } catch {
                try Task.checkCancellation()
                continue
            }
            try Task.checkCancellation()
            guard let prepared else { continue }
            if retained[prepared.identifier] == nil {
                guard prepared.data.count <= 8_388_608 - retainedBytes else { continue }
                retained[prepared.identifier] = prepared
                retainedBytes += prepared.data.count
            }
            resolutions[url] = .resource(prepared.identifier)
            covers[item.mangaID] = retained[prepared.identifier]
        }
        try Task.checkCancellation()
        return covers
    }

    private enum Resolution {
        case unavailable
        case resource(String)
    }
}
