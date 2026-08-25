//
//  CatalogModel.swift
//  MangaLibrary
//

import Observation

@Observable @MainActor
final class CatalogModel {
    typealias PageLoader = @Sendable (CatalogPageRequest) async throws -> CatalogPage

    enum FailureReason: Equatable {
        case unavailable
        case contractDrift
    }

    enum State: Equatable {
        case idle
        case loading
        case content([Manga])
        case empty
        case failure(FailureReason)
    }

    private final class LoadIdentity {}

    private(set) var state = State.idle
    var selectedMangaID: Manga.ID?

    @ObservationIgnored private let loadPage: PageLoader
    @ObservationIgnored private var activeLoadIdentity: LoadIdentity?

    var selectedManga: Manga? {
        guard
            let selectedMangaID,
            case let .content(mangas) = state
        else {
            return nil
        }

        return mangas.first { $0.id == selectedMangaID }
    }

    init(initialState: State = .idle, loadPage: @escaping PageLoader) {
        state = initialState
        self.loadPage = loadPage
    }

    /// Loads the first page only while the feature has not resolved an initial state.
    func loadIfNeeded() async {
        guard state == .idle else {
            return
        }

        await loadInitialPage()
    }

    /// Replaces the current first-page query and invalidates any older response.
    func reload() async {
        await loadInitialPage()
    }

    /// Repeats the failed first-page query without changing its identity.
    func retry() async {
        guard case .failure = state else {
            return
        }

        await loadInitialPage()
    }

    private func loadInitialPage() async {
        do {
            try await load(CatalogPageRequest())
        } catch is CancellationError {
            state = .idle
        } catch CatalogAPIClientError.contractDrift,
                CatalogAPIClientError.duplicateMangaID {
            state = .failure(.contractDrift)
        } catch {
            state = .failure(.unavailable)
        }
    }

    /// Applies a result only while its identity is still the active query.
    ///
    /// Cancellation restores the initial state and is never surfaced as a
    /// recoverable failure. A superseded request cannot mutate visible state,
    /// regardless of the order in which its response arrives.
    private func load(_ request: CatalogPageRequest) async throws {
        let identity = LoadIdentity()
        activeLoadIdentity = identity
        state = .loading

        do {
            let page = try await loadPage(request)
            try Task.checkCancellation()
            guard activeLoadIdentity === identity else {
                return
            }

            activeLoadIdentity = nil
            state = page.items.isEmpty ? .empty : .content(page.items)
        } catch {
            guard activeLoadIdentity === identity else {
                return
            }

            activeLoadIdentity = nil
            throw error
        }
    }
}
