//
//  CollectionAPIClient.swift
//  MangaLibrary
//

import Foundation

enum CollectionAPIClientError: Error, Equatable {
    case unavailable
    case network(NetworkError)
    case contractDrift
    case invalidVolumeState
    case duplicateRemoteID(UUID)
    case duplicateMangaID(Manga.ID)
}

/// One unambiguous decoded member of the remote Collection snapshot.
///
/// The backend UUID proves that the response itself is unambiguous. R1
/// reconciles persistence by the product identity `userID + mangaID`; the
/// remote UUID is intentionally neither persisted nor used by write routes.
/// Value invariants are validated atomically at the persistence boundary.
struct CollectionRemoteEntry: Equatable {
    let remoteID: UUID
    let manga: Manga
    let ownedVolumes: [Int64]
    let readingVolume: Int64?
    let isComplete: Bool
    /// Raw wire value retained so R1 can reject unsupported totals atomically.
    ///
    /// Catalog rejects out-of-policy values before projection. Collection retains
    /// the raw value even when its intermediate `Manga` omits that total; collapsing
    /// it here would turn contract drift into an apparently unknown total.
    let reportedTotalVolumes: Int64?

    init(
        remoteID: UUID,
        manga: Manga,
        ownedVolumes: [Int64],
        readingVolume: Int64?,
        isComplete: Bool,
        reportedTotalVolumes: Int64? = nil
    ) {
        self.remoteID = remoteID
        self.manga = manga
        self.ownedVolumes = ownedVolumes
        self.readingVolume = readingVolume
        self.isComplete = isComplete
        self.reportedTotalVolumes = reportedTotalVolumes ?? manga.totalVolumes
    }
}

struct CollectionAPIClient {
    typealias DataLoader = @Sendable (URLRequest) async throws(any Error) -> Data
    typealias ResponseLoader = @Sendable (URLRequest) async throws(any Error) -> HTTPResponse

    let configuration: APIConfiguration
    let loadData: DataLoader
    let loadResponse: ResponseLoader

    init(
        configuration: APIConfiguration,
        loadData: @escaping DataLoader,
        loadResponse: ResponseLoader? = nil
    ) {
        self.configuration = configuration
        self.loadData = loadData
        self.loadResponse = loadResponse ?? { request in
            HTTPResponse(data: try await loadData(request), statusCode: 200)
        }
    }

    /// Loads the exact authenticated full snapshot exposed by `GET /collection/manga`.
    ///
    /// Transport categories and cancellation retain their meaning. Malformed
    /// DTOs and ambiguous remote identities fail the whole response; neither
    /// response bytes nor the access credential are retained.
    @concurrent
    func fetch(accessToken: String) async throws(any Error) -> [CollectionRemoteEntry] {
        guard accessToken.isEmpty == false else { throw CollectionAPIClientError.unavailable }

        var request = URLRequest(
            url: configuration.baseURL.appending(path: "collection/manga"),
            cachePolicy: .reloadIgnoringLocalCacheData
        )
        request.httpMethod = "GET"
        request.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")

        let data: Data
        do {
            data = try await loadData(request)
        } catch is CancellationError {
            throw CancellationError()
        } catch let error as NetworkError {
            throw CollectionAPIClientError.network(error)
        } catch {
            throw CollectionAPIClientError.unavailable
        }

        try Task.checkCancellation()

        do {
            let response = try JSONDecoder().decode([CollectionEntryDTO].self, from: data)
            return try validatedEntries(response)
        } catch let error as CollectionAPIClientError {
            throw error
        } catch {
            throw CollectionAPIClientError.contractDrift
        }
    }

    /// Loads one manga from the authenticated Collection for DELETE reconciliation.
    ///
    /// The path uses the decimal product identity. Only the endpoint's documented
    /// `404` is represented as absence; every other transport status keeps its
    /// original category so callers cannot mistake deployment drift for success.
    @concurrent
    func fetch(mangaID: Manga.ID, accessToken: String) async throws(any Error) -> CollectionRemoteEntry? {
        guard mangaID > 0, accessToken.isEmpty == false else { throw CollectionAPIClientError.unavailable }

        try Task.checkCancellation()
        var request = URLRequest(
            url: configuration.baseURL.appending(path: "collection/manga/\(mangaID)"),
            cachePolicy: .reloadIgnoringLocalCacheData
        )
        request.httpMethod = "GET"
        request.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")

        let response: HTTPResponse
        do {
            response = try await loadResponse(request)
        } catch is CancellationError {
            throw CancellationError()
        } catch let error as NetworkError {
            throw CollectionAPIClientError.network(error)
        } catch {
            throw CollectionAPIClientError.unavailable
        }

        try Task.checkCancellation()
        if response.statusCode == 404 {
            return nil
        }
        guard response.statusCode == 200 else {
            throw CollectionAPIClientError.network(.statusCode(response.statusCode))
        }

        do {
            let entry = try JSONDecoder().decode(CollectionEntryDTO.self, from: response.data).remoteEntry
            guard entry.manga.id == mangaID else { throw CollectionAPIClientError.contractDrift }
            return entry
        } catch let error as CollectionAPIClientError {
            throw error
        } catch {
            throw CollectionAPIClientError.contractDrift
        }
    }

    /// Sends one non-tombstone Collection intent through the published upsert route.
    ///
    /// The response integer is deliberately opaque. Callers may use successful
    /// decoding as confirmation, but must not treat it as a manga, entry or local
    /// operation identity.
    @concurrent
    func submit(
        mangaID: Manga.ID,
        ownedVolumes: [Int64],
        readingVolume: Int64?,
        isComplete: Bool,
        accessToken: String
    ) async throws(any Error) -> Int64 {
        guard accessToken.isEmpty == false else { throw CollectionAPIClientError.unavailable }
        guard
            ownedVolumes.allSatisfy(CollectionVolumePolicy.contains),
            ownedVolumes == Array(Set(ownedVolumes)).sorted(),
            readingVolume.map(CollectionVolumePolicy.contains) ?? true
        else { throw CollectionAPIClientError.invalidVolumeState }

        let body: Data
        do {
            body = try JSONEncoder().encode(
                CollectionUpsertDTO(
                    manga: mangaID,
                    completeCollection: isComplete,
                    volumesOwned: ownedVolumes,
                    readingVolume: readingVolume
                )
            )
        } catch {
            throw CollectionAPIClientError.contractDrift
        }

        try Task.checkCancellation()
        var request = URLRequest(
            url: configuration.baseURL.appending(path: "collection/manga"),
            cachePolicy: .reloadIgnoringLocalCacheData
        )
        request.httpMethod = "POST"
        request.httpBody = body
        request.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        let data: Data
        do {
            data = try await loadData(request)
        } catch is CancellationError {
            throw CancellationError()
        } catch let error as NetworkError {
            throw CollectionAPIClientError.network(error)
        } catch {
            throw CollectionAPIClientError.unavailable
        }

        try Task.checkCancellation()
        do {
            return try JSONDecoder().decode(Int64.self, from: data)
        } catch {
            throw CollectionAPIClientError.contractDrift
        }
    }

    /// Removes one manga through the published Collection route.
    ///
    /// The returned integer is opaque. A non-`200` status, including `404`, is
    /// deliberately left uncertain so the coordinator can reconcile it with one
    /// safe individual GET instead of repeating a potentially completed DELETE.
    @concurrent
    func remove(mangaID: Manga.ID, accessToken: String) async throws(any Error) -> Int64 {
        guard mangaID > 0, accessToken.isEmpty == false else { throw CollectionAPIClientError.unavailable }

        try Task.checkCancellation()
        var request = URLRequest(
            url: configuration.baseURL.appending(path: "collection/manga/\(mangaID)"),
            cachePolicy: .reloadIgnoringLocalCacheData
        )
        request.httpMethod = "DELETE"
        request.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")

        let data: Data
        do {
            data = try await loadData(request)
        } catch is CancellationError {
            throw CancellationError()
        } catch let error as NetworkError {
            throw CollectionAPIClientError.network(error)
        } catch {
            throw CollectionAPIClientError.unavailable
        }

        try Task.checkCancellation()
        do {
            return try JSONDecoder().decode(Int64.self, from: data)
        } catch {
            throw CollectionAPIClientError.contractDrift
        }
    }

    private func validatedEntries(
        _ response: [CollectionEntryDTO]
    ) throws(CollectionAPIClientError) -> [CollectionRemoteEntry] {
        var remoteIDs: Set<UUID> = []
        var mangaIDs: Set<Manga.ID> = []
        var entries: [CollectionRemoteEntry] = []
        entries.reserveCapacity(response.count)

        for item in response {
            guard remoteIDs.insert(item.id).inserted else { throw .duplicateRemoteID(item.id) }

            let entry = item.remoteEntry
            guard mangaIDs.insert(entry.manga.id).inserted else { throw .duplicateMangaID(entry.manga.id) }
            entries.append(entry)
        }

        return entries
    }
}

extension CollectionAPIClient {
    /// Adapts the shared production transport without exposing it to feature tests.
    init(httpClient: HTTPClient, configuration: APIConfiguration) {
        self.init(
            configuration: configuration,
            loadData: { request in try await httpClient.data(for: request) },
            loadResponse: { request in
                try await httpClient.response(for: request, accepting: [200, 404])
            }
        )
    }
}

private struct CollectionEntryDTO: Decodable {
    let id: UUID
    let manga: MangaDTO
    let completeCollection: Bool
    let volumesOwned: [Int64]
    let readingVolume: Int64?

    var remoteEntry: CollectionRemoteEntry {
        CollectionRemoteEntry(
            remoteID: id,
            manga: manga.manga(),
            ownedVolumes: volumesOwned,
            readingVolume: readingVolume,
            isComplete: completeCollection,
            reportedTotalVolumes: manga.reportedTotalVolumes
        )
    }
}

private struct CollectionUpsertDTO: Encodable {
    let manga: Manga.ID
    let completeCollection: Bool
    let volumesOwned: [Int64]
    let readingVolume: Int64?

    private enum CodingKeys: String, CodingKey {
        case manga
        case completeCollection
        case volumesOwned
        case readingVolume
    }

    func encode(to encoder: any Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(manga, forKey: .manga)
        try container.encode(completeCollection, forKey: .completeCollection)
        try container.encode(volumesOwned, forKey: .volumesOwned)
        if let readingVolume {
            try container.encode(readingVolume, forKey: .readingVolume)
        } else {
            try container.encodeNil(forKey: .readingVolume)
        }
    }
}
