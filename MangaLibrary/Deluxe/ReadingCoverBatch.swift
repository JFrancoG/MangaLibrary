import Foundation

/// Prepares optional images only for candidates that could fit without covers.
///
/// Input is fetched sequentially outside the caller's actor. Supply bounded bytes, such as
/// `ReadingCoverSource.data(from:)`; source buffers are not cached. Repeated URLs, including
/// failures, are resolved once and identical JPEGs share one retained value within eight MiB.
/// Failed sources are placeholders, cancellation aborts the batch, and no resource is admitted
/// to durable storage here. Publication must still select its final prefix and recheck authority.
enum ReadingCoverBatch {
    @concurrent
    static func prepare(
        projection: CollectionReadingProjection,
        loadSource: @Sendable (URL) async throws -> Data?
    ) async throws -> [Manga.ID: ReadingCoverResource] {
        let plan = try ReadingPublicationPlan(projection: projection)
        var resolutions: [URL: Resolution] = [:]
        var retained: [String: ReadingCoverResource] = [:]
        var retainedBytes = 0
        var covers: [Manga.ID: ReadingCoverResource] = [:]
        for item in projection.items.prefix(plan.items.count) {
            try Task.checkCancellation()
            guard let url = item.coverURL else { continue }
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
                prepared = try ReadingCoverPreparation.prepare(source)
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
