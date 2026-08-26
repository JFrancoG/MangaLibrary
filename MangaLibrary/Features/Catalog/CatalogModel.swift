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

    enum Pagination: Equatable {
        case ready(nextPage: Int64)
        case loading(page: Int64)
        case failure(page: Int64, reason: FailureReason)
        case end
    }

    struct Content: Equatable {
        let items: [Manga]
        let pagination: Pagination
    }

    enum State: Equatable {
        case idle
        case loading
        case content(Content)
        case empty
        case failure(FailureReason)
    }

    private final class LoadIdentity {}

    private(set) var state = State.idle
    private(set) var requestedNextPage: Int64?
    var selectedMangaID: Manga.ID?

    @ObservationIgnored private let loadPage: PageLoader
    @ObservationIgnored private var activeLoadIdentity: LoadIdentity?

    var selectedManga: Manga? {
        guard
            let selectedMangaID,
            case let .content(content) = state
        else {
            return nil
        }

        return content.items.first { $0.id == selectedMangaID }
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

    /// Replaces the current query and invalidates any initial or additional response.
    func reload() async {
        requestedNextPage = nil
        await loadInitialPage()
    }

    /// Repeats the failed first-page query without changing its identity.
    func retry() async {
        guard case .failure = state else {
            return
        }

        await loadInitialPage()
    }

    /// Requests another page only after the final visible manga reaches the UI.
    ///
    /// Repeated appearances and calls while a request is pending are idempotent.
    /// Reaching ``Pagination/end`` cannot schedule more network work.
    func requestNextPageIfNeeded(after mangaID: Manga.ID) {
        guard
            requestedNextPage == nil,
            case let .content(content) = state,
            content.items.last?.id == mangaID,
            case let .ready(nextPage) = content.pagination
        else {
            return
        }

        requestedNextPage = nextPage
    }

    /// Schedules the exact additional page retained by a recoverable failure.
    func requestNextPageRetry() {
        guard
            requestedNextPage == nil,
            case let .content(content) = state,
            case let .failure(page, _) = content.pagination
        else {
            return
        }

        requestedNextPage = page
    }

    /// Loads the additional page requested by the current catalog presentation.
    ///
    /// Existing content remains visible while loading and after failure. Cancellation
    /// restores the prior pagination state, retry keeps the same page, and a response
    /// superseded by reload cannot mutate the current query. Items already integrated
    /// keep their value when a later page repeats the same ``Manga/id``.
    func loadRequestedNextPage() async {
        guard
            let requestedNextPage,
            case let .content(content) = state,
            content.pagination.canLoad(page: requestedNextPage)
        else {
            return
        }

        state = .content(
            Content(
                items: content.items,
                pagination: .loading(page: requestedNextPage)
            )
        )

        do {
            let request = try CatalogPageRequest(page: requestedNextPage)
            guard let page = try await fetchPage(request) else {
                return
            }

            let integration = integrate(
                page.items,
                into: content.items
            )
            let pagination = pagination(after: page)
            state = .content(
                Content(
                    items: integration.items,
                    pagination: pagination
                )
            )

            if integration.appendedCount == 0,
               case let .ready(nextPage) = pagination {
                self.requestedNextPage = nextPage
            } else {
                self.requestedNextPage = nil
            }
        } catch is CancellationError {
            self.requestedNextPage = nil
            state = .content(content)
        } catch {
            self.requestedNextPage = nil
            state = .content(
                Content(
                    items: content.items,
                    pagination: .failure(
                        page: requestedNextPage,
                        reason: failureReason(for: error)
                    )
                )
            )
        }
    }

    private func loadInitialPage() async {
        let previousState = state
        state = .loading

        do {
            let request = try CatalogPageRequest()
            guard let page = try await fetchPage(request) else {
                return
            }

            if page.items.isEmpty {
                state = .empty
            } else {
                state = .content(
                    Content(
                        items: page.items,
                        pagination: pagination(after: page)
                    )
                )
            }
        } catch is CancellationError {
            state = previousState
        } catch {
            state = .failure(failureReason(for: error))
        }
    }

    /// Returns a result only while its identity remains the active query.
    private func fetchPage(_ request: CatalogPageRequest) async throws -> CatalogPage? {
        let identity = LoadIdentity()
        activeLoadIdentity = identity

        do {
            let page = try await loadPage(request)
            try Task.checkCancellation()
            guard activeLoadIdentity === identity else {
                return nil
            }

            activeLoadIdentity = nil
            return page
        } catch {
            guard activeLoadIdentity === identity else {
                return nil
            }

            activeLoadIdentity = nil
            throw error
        }
    }

    private func failureReason(for error: any Error) -> FailureReason {
        guard let clientError = error as? CatalogAPIClientError else {
            return .unavailable
        }

        switch clientError {
        case .unavailable:
            return .unavailable
        case .contractDrift, .duplicateMangaID:
            return .contractDrift
        }
    }

    private func pagination(after page: CatalogPage) -> Pagination {
        let metadata = page.metadata
        guard
            !page.items.isEmpty,
            metadata.total > 0,
            metadata.per > 0
        else {
            return .end
        }

        let completePages = metadata.total / metadata.per
        let totalPages = completePages
            + (metadata.total.isMultiple(of: metadata.per) ? 0 : 1)
        guard
            metadata.page < totalPages,
            metadata.page < Int64.max
        else {
            return .end
        }

        return .ready(nextPage: metadata.page + 1)
    }

    private func integrate(
        _ newItems: [Manga],
        into existingItems: [Manga]
    ) -> (items: [Manga], appendedCount: Int) {
        var identities = Set(existingItems.map(\.id))
        var items = existingItems
        items.reserveCapacity(existingItems.count + newItems.count)

        for item in newItems where identities.insert(item.id).inserted {
            items.append(item)
        }

        return (items, items.count - existingItems.count)
    }
}

private extension CatalogModel.Pagination {
    func canLoad(page: Int64) -> Bool {
        switch self {
        case let .ready(nextPage):
            nextPage == page
        case let .failure(failedPage, _):
            failedPage == page
        case .loading, .end:
            false
        }
    }
}
