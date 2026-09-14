//
//  CatalogModel.swift
//  MangaLibrary
//

import Foundation
import Observation

@Observable @MainActor
final class CatalogModel {
    typealias PageLoader = @Sendable (CatalogPageRequest) async throws -> CatalogPage
    typealias FilterOptionsLoader = @Sendable () async throws -> CatalogFilterOptions

    enum FailureReason: Equatable {
        case unavailable
        case network(NetworkError)
        case contractDrift

        /// A safe, deferred description for the current SwiftUI locale.
        var errorDescriptionResource: LocalizedStringResource {
            switch self {
            case .unavailable:
                "The catalog is temporarily unavailable."
            case let .network(error):
                error.errorDescriptionResource
            case .contractDrift:
                "The server response has an unexpected format."
            }
        }
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

    enum FilterOptionsState: Equatable {
        case idle
        case loading
        case content(CatalogFilterOptions)
        case failure(FailureReason)
    }

    private final class LoadIdentity {}
    private static let paginationPrefetchItemCount = 2

    private(set) var state = State.idle
    private(set) var query: CatalogQuery
    private(set) var requestedNextPage: Int64?
    private(set) var filterOptionsState: FilterOptionsState
    var selectedMangaID: Manga.ID?

    @ObservationIgnored private let loadPage: PageLoader
    @ObservationIgnored private let fetchFilterOptions: FilterOptionsLoader
    @ObservationIgnored private var activePageLoadIdentity: LoadIdentity?
    @ObservationIgnored private var activeFilterOptionsLoadIdentity: LoadIdentity?
    @ObservationIgnored private var sourceFilterOptions: CatalogFilterOptions?

    var selectedManga: Manga? {
        guard let selectedMangaID else { return nil }

        return manga(id: selectedMangaID)
    }

    func manga(id: Manga.ID) -> Manga? {
        guard case let .content(content) = state else { return nil }

        return content.items.first { $0.id == id }
    }

    init(
        initialState: State = .idle,
        initialQuery: CatalogQuery = .catalog,
        initialFilterOptionsState: FilterOptionsState = .idle,
        loadFilterOptions: @escaping FilterOptionsLoader = { .empty },
        loadPage: @escaping PageLoader
    ) {
        state = initialState
        query = initialQuery
        switch initialFilterOptionsState {
        case let .content(options):
            sourceFilterOptions = options
            filterOptionsState = .content(Self.preparedFilterOptions(options, for: initialQuery))
        case .idle, .loading, .failure:
            filterOptionsState = initialFilterOptionsState
        }
        fetchFilterOptions = loadFilterOptions
        self.loadPage = loadPage
    }

    /// Applies a complete catalog-query identity without starting unstructured work.
    ///
    /// Text and filters participate in ``CatalogQuery`` equality. A different value
    /// clears selection and pagination, restores the first-page state, and invalidates
    /// any response belonging to the previous query. Reapplying the same value is a
    /// no-op so the current presentation remains stable.
    func apply(query: CatalogQuery) {
        guard self.query != query else { return }

        activePageLoadIdentity = nil
        self.query = query
        if let sourceFilterOptions, case .content = filterOptionsState {
            filterOptionsState = .content(Self.preparedFilterOptions(sourceFilterOptions, for: query))
        }
        requestedNextPage = nil
        selectedMangaID = nil
        state = .idle
    }

    /// Loads the first page only while the feature has not resolved an initial state.
    ///
    /// Reentry replaces an active initial load, including one whose view task is
    /// still cancelling. Prepared loading states without an active request remain
    /// unchanged, and results from a replaced load cannot update the presentation.
    func loadIfNeeded() async {
        switch state {
        case .idle:
            await loadInitialPage()
        case .loading:
            guard activePageLoadIdentity != nil else { return }

            await loadInitialPage()
        case .content, .empty, .failure:
            return
        }
    }

    /// Reloads the first page of the current query and invalidates older page responses.
    func reload() async {
        requestedNextPage = nil
        await loadInitialPage()
    }

    /// Repeats the failed first-page query without changing its identity.
    func retry() async {
        guard case .failure = state else { return }

        await loadInitialPage()
    }

    /// Loads filter vocabularies while their independent state is unresolved.
    ///
    /// Page-query changes do not supersede this work. Reentry while a previous view
    /// task is still cancelling replaces its load identity, preventing a stale
    /// cancellation or response from leaving the feature idle without a new request.
    func loadFilterOptionsIfNeeded() async {
        switch filterOptionsState {
        case .idle:
            await loadFilterOptions(previousState: .idle)
        case .loading:
            guard activeFilterOptionsLoadIdentity != nil else { return }

            await loadFilterOptions(previousState: .idle)
        case .content, .failure:
            return
        }
    }

    /// Repeats a failed filter-options request without affecting catalog results.
    func retryFilterOptions() async {
        guard case .failure = filterOptionsState else { return }

        await loadFilterOptions(previousState: filterOptionsState)
    }

    /// Requests another page when one of the final two mangas reaches the UI.
    ///
    /// Repeated appearances and calls while a request is pending are idempotent.
    /// Reaching ``Pagination/end`` cannot schedule more network work.
    func requestNextPageIfNeeded(after mangaID: Manga.ID) {
        guard
            requestedNextPage == nil,
            case let .content(content) = state,
            content.items
                .suffix(Self.paginationPrefetchItemCount)
                .contains(where: { $0.id == mangaID }),
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

        state = .content(Content(items: content.items, pagination: .loading(page: requestedNextPage)))

        do {
            let request = try CatalogPageRequest(query: query, page: requestedNextPage)
            guard let page = try await fetchPage(request) else { return }

            let integration = integrate(page.items, into: content.items)
            let pagination = pagination(after: page)
            state = .content(Content(items: integration.items, pagination: pagination))

            if integration.appendedCount == 0, case let .ready(nextPage) = pagination {
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
                    pagination: .failure(page: requestedNextPage, reason: failureReason(for: error))
                )
            )
        }
    }

    private func loadInitialPage() async {
        let previousState: State = state == .loading ? .idle : state
        state = .loading

        do {
            let request = try CatalogPageRequest(query: query)
            guard let page = try await fetchPage(request) else { return }

            if page.items.isEmpty {
                state = .empty
            } else {
                state = .content(Content(items: page.items, pagination: pagination(after: page)))
            }
        } catch is CancellationError {
            state = previousState
        } catch {
            state = .failure(failureReason(for: error))
        }
    }

    /// Returns a result only while its identity remains the active page query.
    private func fetchPage(_ request: CatalogPageRequest) async throws -> CatalogPage? {
        let identity = LoadIdentity()
        activePageLoadIdentity = identity

        do {
            let page = try await loadPage(request)
            try Task.checkCancellation()
            guard activePageLoadIdentity === identity else { return nil }

            activePageLoadIdentity = nil
            return page
        } catch {
            guard activePageLoadIdentity === identity else { return nil }

            activePageLoadIdentity = nil
            throw error
        }
    }

    private func loadFilterOptions(previousState: FilterOptionsState) async {
        let identity = LoadIdentity()
        activeFilterOptionsLoadIdentity = identity
        filterOptionsState = .loading

        do {
            let options = try await fetchFilterOptions()
            try Task.checkCancellation()
            guard activeFilterOptionsLoadIdentity === identity else { return }

            activeFilterOptionsLoadIdentity = nil
            sourceFilterOptions = options
            filterOptionsState = .content(Self.preparedFilterOptions(options, for: query))
        } catch is CancellationError {
            guard activeFilterOptionsLoadIdentity === identity else { return }

            activeFilterOptionsLoadIdentity = nil
            filterOptionsState = previousState
        } catch {
            guard activeFilterOptionsLoadIdentity === identity else { return }

            activeFilterOptionsLoadIdentity = nil
            filterOptionsState = .failure(failureReason(for: error))
        }
    }

    private func failureReason(for error: any Error) -> FailureReason {
        guard let clientError = error as? CatalogAPIClientError else { return .unavailable }

        switch clientError {
        case .unavailable:
            return .unavailable
        case let .network(error):
            return .network(error)
        case .contractDrift, .duplicateMangaID:
            return .contractDrift
        }
    }

    private static func preparedFilterOptions(
        _ options: CatalogFilterOptions,
        for query: CatalogQuery
    ) -> CatalogFilterOptions {
        guard let search = query.advancedSearch else { return options }

        return options.includingSelections(
            demographics: Set(search.demographics),
            genres: Set(search.genres),
            themes: Set(search.themes)
        )
    }

    private func pagination(after page: CatalogPage) -> Pagination {
        let metadata = page.metadata
        guard !page.items.isEmpty, metadata.total > 0, metadata.per > 0 else { return .end }

        let completePages = metadata.total / metadata.per
        let totalPages = completePages + (metadata.total.isMultiple(of: metadata.per) ? 0 : 1)
        guard metadata.page < totalPages, metadata.page < Int64.max else { return .end }

        return .ready(nextPage: metadata.page + 1)
    }

    private func integrate(_ newItems: [Manga], into existingItems: [Manga]) -> (items: [Manga], appendedCount: Int) {
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
