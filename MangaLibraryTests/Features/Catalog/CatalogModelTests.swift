//
//  CatalogModelTests.swift
//  MangaLibraryTests
//

import Foundation
import Testing
@testable import MangaLibrary

@Suite(.tags(.fast))
@MainActor
struct CatalogModelTests {
    @Test
    func loadTransitionsFromIdleThroughLoadingToContent() async throws {
        let loader = ControlledCatalogLoader()
        let model = makeModel(loader: loader)
        let expectedPage = page(items: [manga(id: 1, title: "One Piece")])

        #expect(model.state == .idle)

        let loadTask = Task {
            await model.loadIfNeeded()
        }
        await loader.waitForRequestCount(1)

        #expect(model.state == .loading)

        await loader.succeed(expectedPage, at: 0)
        await loadTask.value

        #expect(model.state == terminalContent(expectedPage.items))

        await model.loadIfNeeded()

        #expect(await loader.requests().count == 1)
        #expect(model.state == terminalContent(expectedPage.items))
    }

    @Test
    func emptyInitialPageProducesEmptyState() async {
        let emptyPage = page(items: [])
        let model = CatalogModel { _ in emptyPage }

        await model.loadIfNeeded()

        #expect(model.state == .empty)
    }

    @Test
    func recoverableFailureRetriesTheSameRequest() async throws {
        let loader = ControlledCatalogLoader()
        let model = makeModel(loader: loader)
        let expectedRequest = try CatalogPageRequest()
        let recoveredPage = page(items: [manga(id: 2, title: "Monster")])

        let initialTask = Task {
            await model.loadIfNeeded()
        }
        await loader.waitForRequestCount(1)
        await loader.fail(CatalogAPIClientError.network(.transport(.notConnectedToInternet)), at: 0)
        await initialTask.value

        #expect(model.state == .failure(.network(.transport(.notConnectedToInternet))))

        let retryTask = Task {
            await model.retry()
        }
        await loader.waitForRequestCount(2)

        #expect(await loader.requests() == [expectedRequest, expectedRequest])

        await loader.succeed(recoveredPage, at: 1)
        await retryTask.value

        #expect(model.state == terminalContent(recoveredPage.items))
    }

    @Test
    func contractDriftRemainsObservableInFailureState() async {
        let model = CatalogModel { _ in
            throw CatalogAPIClientError.contractDrift
        }

        await model.loadIfNeeded()

        #expect(model.state == .failure(.contractDrift))
    }

    @Test
    func cancellationNeverBecomesAVisibleFailure() async {
        let loader = ControlledCatalogLoader()
        let model = makeModel(loader: loader)

        let loadTask = Task {
            await model.loadIfNeeded()
        }
        await loader.waitForRequestCount(1)

        loadTask.cancel()
        await loader.waitForCancellation(at: 0)
        await loadTask.value

        #expect(await loader.wasCancelled(at: 0))
        #expect(model.state == .idle)
    }

    @Test(arguments: [false, true])
    func reentryDuringCancellationLoadsFreshContent(returnsStalePage: Bool) async throws {
        let currentPage = page(items: [manga(id: 4, title: "Current")])
        let loader = ReentrantCatalogPageLoader(subsequentPage: currentPage)
        let model = CatalogModel { request in
            try await loader.load(request)
        }
        let expectedRequest = try CatalogPageRequest()

        let firstTask = Task {
            await model.loadIfNeeded()
        }
        await loader.waitForFirstRequest()
        firstTask.cancel()

        await model.loadIfNeeded()

        #expect(await loader.requests == [expectedRequest, expectedRequest])
        #expect(model.state == terminalContent(currentPage.items))

        let completion: Result<CatalogPage, any Error> = returnsStalePage
            ? .success(page(items: [manga(id: 3, title: "Stale")]))
            : .failure(CancellationError())
        await loader.completeFirstRequest(with: completion)
        await firstTask.value

        #expect(model.state == terminalContent(currentPage.items))
    }

    @Test
    func cancellingReloadDuringInitialLoadAllowsAnotherEntry() async throws {
        let loader = ControlledCatalogLoader()
        let model = makeModel(loader: loader)
        let currentPage = page(items: [manga(id: 4, title: "Current")])

        let firstTask = Task {
            await model.loadIfNeeded()
        }
        await loader.waitForRequestCount(1)
        let reloadTask = Task {
            await model.reload()
        }
        await loader.waitForRequestCount(2)

        reloadTask.cancel()
        await loader.waitForCancellation(at: 1)
        await reloadTask.value
        #expect(model.state == .idle)

        await loader.succeed(page(items: [manga(id: 3, title: "Stale")]), at: 0)
        await firstTask.value
        try #require(model.state == .idle)

        let recoveryTask = Task {
            await model.loadIfNeeded()
        }
        await loader.waitForRequestCount(3)
        await loader.succeed(currentPage, at: 2)
        await recoveryTask.value

        #expect(model.state == terminalContent(currentPage.items))
    }

    @Test
    func preparedLoadingStateDoesNotStartARequest() async {
        let model = CatalogModel(initialState: .loading) { _ in
            Issue.record("A prepared loading state must not start a request")
            return CatalogPage(items: [], metadata: .init(page: 1, per: 20, total: 0))
        }

        await model.loadIfNeeded()

        #expect(model.state == .loading)
    }

    @Test
    func lateSupersededResponseCannotReplaceCurrentContent() async {
        let loader = ControlledCatalogLoader()
        let model = makeModel(loader: loader)
        let stalePage = page(items: [manga(id: 3, title: "Stale")])
        let currentPage = page(items: [manga(id: 4, title: "Current")])

        let staleTask = Task {
            await model.loadIfNeeded()
        }
        await loader.waitForRequestCount(1)

        let currentTask = Task {
            await model.reload()
        }
        await loader.waitForRequestCount(2)

        await loader.succeed(currentPage, at: 1)
        await currentTask.value
        #expect(model.state == terminalContent(currentPage.items))

        await loader.succeed(stalePage, at: 0)
        await staleTask.value

        #expect(model.state == terminalContent(currentPage.items))
    }

    @Test
    func lateSupersededFailureCannotReplaceCurrentContent() async {
        let loader = ControlledCatalogLoader()
        let model = makeModel(loader: loader)
        let currentPage = page(items: [manga(id: 8, title: "Vinland Saga")])

        let staleTask = Task {
            await model.loadIfNeeded()
        }
        await loader.waitForRequestCount(1)

        let currentTask = Task {
            await model.reload()
        }
        await loader.waitForRequestCount(2)

        await loader.succeed(currentPage, at: 1)
        await currentTask.value
        #expect(model.state == terminalContent(currentPage.items))

        await loader.fail(CatalogAPIClientError.network(.transport(.timedOut)), at: 0)
        await staleTask.value

        #expect(model.state == terminalContent(currentPage.items))
    }

    @Test
    func nextPageAccumulatesUniqueMangaAndPreservesSelection() async throws {
        let loader = ControlledCatalogLoader()
        let model = makeModel(loader: loader)
        let firstManga = manga(id: 10, title: "Berserk")
        let selectedManga = manga(id: 11, title: "Vagabond")
        let appendedManga = manga(id: 12, title: "Slam Dunk")
        let expectedSecondRequest = try CatalogPageRequest(page: 2)

        let initialTask = Task {
            await model.loadIfNeeded()
        }
        await loader.waitForRequestCount(1)
        await loader.succeed(page(number: 1, total: 40, items: [firstManga, selectedManga]), at: 0)
        await initialTask.value
        model.selectedMangaID = selectedManga.id

        model.requestNextPageIfNeeded(after: selectedManga.id)
        #expect(model.requestedNextPage == 2)

        let nextPageTask = Task {
            await model.loadRequestedNextPage()
        }
        await loader.waitForRequestCount(2)
        #expect(await loader.requests().last == expectedSecondRequest)

        await loader.succeed(
            page(
                number: 2,
                total: 40,
                items: [manga(id: selectedManga.id, title: "Changed duplicate"), appendedManga]
            ),
            at: 1
        )
        await nextPageTask.value

        #expect(model.state == .content(.init(items: [firstManga, selectedManga, appendedManga], pagination: .end)))
        #expect(model.selectedManga == selectedManga)
        #expect(model.requestedNextPage == nil)
    }

    @Test
    func terminalFirstPageNeverRequestsAnotherPage() async {
        let loader = ControlledCatalogLoader()
        let model = makeModel(loader: loader)
        let onlyManga = manga(id: 20, title: "Akira")

        let initialTask = Task {
            await model.loadIfNeeded()
        }
        await loader.waitForRequestCount(1)
        await loader.succeed(page(number: 1, total: 1, items: [onlyManga]), at: 0)
        await initialTask.value

        model.requestNextPageIfNeeded(after: onlyManga.id)
        await model.loadRequestedNextPage()

        #expect(model.requestedNextPage == nil)
        #expect(await loader.requests().count == 1)
        #expect(model.state == .content(.init(items: [onlyManga], pagination: .end)))
    }

    @Test
    func approachingTheLastTwoItemsRequestsTheNextPageOnlyOnce() {
        let items = (1...20).map {
            manga(id: Manga.ID($0), title: "Manga \($0)")
        }
        let emptyPage = page(items: [])
        let model = CatalogModel(initialState: .content(.init(items: items, pagination: .ready(nextPage: 2)))) { _ in
            emptyPage
        }

        model.requestNextPageIfNeeded(after: items[17].id)
        #expect(model.requestedNextPage == nil)

        model.requestNextPageIfNeeded(after: items[18].id)
        model.requestNextPageIfNeeded(after: items[19].id)

        #expect(model.requestedNextPage == 2)
    }

    @Test
    func emptyAdditionalPageEndsPaginationWithoutRemovingContent() async {
        let loader = ControlledCatalogLoader()
        let model = makeModel(loader: loader)
        let firstManga = manga(id: 30, title: "Nausicaa")

        let initialTask = Task {
            await model.loadIfNeeded()
        }
        await loader.waitForRequestCount(1)
        await loader.succeed(page(number: 1, total: 41, items: [firstManga]), at: 0)
        await initialTask.value

        model.requestNextPageIfNeeded(after: firstManga.id)
        let nextPageTask = Task {
            await model.loadRequestedNextPage()
        }
        await loader.waitForRequestCount(2)
        await loader.succeed(page(number: 2, total: 41, items: []), at: 1)
        await nextPageTask.value

        #expect(model.state == .content(.init(items: [firstManga], pagination: .end)))

        model.requestNextPageIfNeeded(after: firstManga.id)
        await model.loadRequestedNextPage()
        #expect(await loader.requests().count == 2)
    }

    @Test
    func additionalFailureRetainsContentAndRetriesTheSamePage() async throws {
        let loader = ControlledCatalogLoader()
        let model = makeModel(loader: loader)
        let firstManga = manga(id: 40, title: "Dragon Ball")
        let secondManga = manga(id: 41, title: "Dr. Slump")

        let initialTask = Task {
            await model.loadIfNeeded()
        }
        await loader.waitForRequestCount(1)
        await loader.succeed(page(number: 1, total: 41, items: [firstManga]), at: 0)
        await initialTask.value

        model.requestNextPageIfNeeded(after: firstManga.id)
        let failedTask = Task {
            await model.loadRequestedNextPage()
        }
        await loader.waitForRequestCount(2)
        await loader.fail(CatalogAPIClientError.network(.transport(.notConnectedToInternet)), at: 1)
        await failedTask.value

        #expect(
            model.state == .content(
                .init(
                    items: [firstManga],
                    pagination: .failure(page: 2, reason: .network(.transport(.notConnectedToInternet)))
                )
            )
        )
        #expect(model.requestedNextPage == nil)

        model.requestNextPageRetry()
        #expect(model.requestedNextPage == 2)
        let retryTask = Task {
            await model.loadRequestedNextPage()
        }
        await loader.waitForRequestCount(3)
        #expect(
            await loader.requests() == [
                try CatalogPageRequest(),
                try CatalogPageRequest(page: 2),
                try CatalogPageRequest(page: 2)
            ]
        )
        await loader.succeed(page(number: 2, total: 41, items: [secondManga]), at: 2)
        await retryTask.value

        #expect(model.state == .content(.init(items: [firstManga, secondManga], pagination: .ready(nextPage: 3))))
    }

    @Test
    func cancellingAnAdditionalPageRestoresItsReadyState() async {
        let loader = ControlledCatalogLoader()
        let model = makeModel(loader: loader)
        let firstManga = manga(id: 50, title: "Phoenix")

        let initialTask = Task {
            await model.loadIfNeeded()
        }
        await loader.waitForRequestCount(1)
        await loader.succeed(page(number: 1, total: 41, items: [firstManga]), at: 0)
        await initialTask.value

        model.requestNextPageIfNeeded(after: firstManga.id)
        let nextPageTask = Task {
            await model.loadRequestedNextPage()
        }
        await loader.waitForRequestCount(2)

        nextPageTask.cancel()
        await loader.waitForCancellation(at: 1)
        await nextPageTask.value

        #expect(await loader.wasCancelled(at: 1))
        #expect(model.requestedNextPage == nil)
        #expect(model.state == .content(.init(items: [firstManga], pagination: .ready(nextPage: 2))))
    }

    @Test
    func lateAdditionalPageCannotContaminateReloadedContent() async {
        let loader = ControlledCatalogLoader()
        let model = makeModel(loader: loader)
        let staleManga = manga(id: 60, title: "Stale page")
        let currentManga = manga(id: 61, title: "Current page")

        let initialTask = Task {
            await model.loadIfNeeded()
        }
        await loader.waitForRequestCount(1)
        await loader.succeed(page(number: 1, total: 41, items: [staleManga]), at: 0)
        await initialTask.value

        model.requestNextPageIfNeeded(after: staleManga.id)
        let staleTask = Task {
            await model.loadRequestedNextPage()
        }
        await loader.waitForRequestCount(2)

        let reloadTask = Task {
            await model.reload()
        }
        await loader.waitForRequestCount(3)
        await loader.succeed(page(number: 1, total: 1, items: [currentManga]), at: 2)
        await reloadTask.value

        await loader.succeed(page(number: 2, total: 41, items: [staleManga]), at: 1)
        await staleTask.value

        #expect(model.state == .content(.init(items: [currentManga], pagination: .end)))
        #expect(model.requestedNextPage == nil)
    }

    @Test
    func applyingDifferentQueryClearsPresentationAndStartsAtFirstPage() async throws {
        let loader = ControlledCatalogLoader()
        let model = makeModel(loader: loader)
        let selectedManga = manga(id: 70, title: "Selected")
        let replacementManga = manga(id: 71, title: "Replacement")
        let replacementQuery = advancedQuery()

        let initialTask = Task {
            await model.loadIfNeeded()
        }
        await loader.waitForRequestCount(1)
        await loader.succeed(page(number: 1, total: 41, items: [selectedManga]), at: 0)
        await initialTask.value
        model.selectedMangaID = selectedManga.id
        model.requestNextPageIfNeeded(after: selectedManga.id)

        #expect(model.requestedNextPage == 2)

        model.apply(query: replacementQuery)

        #expect(model.query == replacementQuery)
        #expect(model.state == .idle)
        #expect(model.requestedNextPage == nil)
        #expect(model.selectedMangaID == nil)

        let replacementTask = Task {
            await model.loadIfNeeded()
        }
        await loader.waitForRequestCount(2)
        #expect(
            await loader.requests() == [
                try CatalogPageRequest(),
                try CatalogPageRequest(query: replacementQuery, page: 1, per: 20)
            ]
        )
        await loader.succeed(page(items: [replacementManga]), at: 1)
        await replacementTask.value

        #expect(model.state == terminalContent([replacementManga]))
    }

    @Test
    func applyingSameQueryPreservesPresentationWithoutLoading() async {
        let loader = ControlledCatalogLoader()
        let model = makeModel(loader: loader)
        let selectedManga = manga(id: 80, title: "Selected")

        let initialTask = Task {
            await model.loadIfNeeded()
        }
        await loader.waitForRequestCount(1)
        await loader.succeed(page(number: 1, total: 41, items: [selectedManga]), at: 0)
        await initialTask.value
        model.selectedMangaID = selectedManga.id
        model.requestNextPageIfNeeded(after: selectedManga.id)
        let stateBeforeApplying = model.state

        model.apply(query: .catalog)

        #expect(model.query == .catalog)
        #expect(model.state == stateBeforeApplying)
        #expect(model.requestedNextPage == 2)
        #expect(model.selectedMangaID == selectedManga.id)
        #expect(await loader.requests().count == 1)
    }

    @Test
    func responseFromPreviousQueryCannotReplaceBestResults() async throws {
        let loader = ControlledCatalogLoader()
        let model = makeModel(loader: loader)
        let staleManga = manga(id: 90, title: "Stale catalog")
        let bestManga = manga(id: 91, title: "Best manga")

        let staleTask = Task {
            await model.loadIfNeeded()
        }
        await loader.waitForRequestCount(1)

        model.apply(query: .best)
        let bestTask = Task {
            await model.loadIfNeeded()
        }
        await loader.waitForRequestCount(2)

        #expect(
            await loader.requests() == [
                try CatalogPageRequest(),
                try CatalogPageRequest(query: .best, page: 1, per: 20)
            ]
        )

        await loader.succeed(page(items: [bestManga]), at: 1)
        await bestTask.value
        #expect(model.state == terminalContent([bestManga]))

        await loader.succeed(page(items: [staleManga]), at: 0)
        await staleTask.value

        #expect(model.query == .best)
        #expect(model.state == terminalContent([bestManga]))
    }

    @Test
    func additionalPageAndRetryPreserveAdvancedQueryIdentity() async throws {
        let loader = ControlledCatalogLoader()
        let model = makeModel(loader: loader)
        let query = advancedQuery()
        let firstManga = manga(id: 100, title: "First")
        let secondManga = manga(id: 101, title: "Second")
        let firstRequest = try CatalogPageRequest(query: query, page: 1, per: 20)
        let secondRequest = try CatalogPageRequest(query: query, page: 2, per: 20)

        model.apply(query: query)
        let initialTask = Task {
            await model.loadIfNeeded()
        }
        await loader.waitForRequestCount(1)
        await loader.succeed(page(number: 1, total: 41, items: [firstManga]), at: 0)
        await initialTask.value

        model.requestNextPageIfNeeded(after: firstManga.id)
        let failedTask = Task {
            await model.loadRequestedNextPage()
        }
        await loader.waitForRequestCount(2)
        await loader.fail(CatalogAPIClientError.network(.transport(.notConnectedToInternet)), at: 1)
        await failedTask.value

        model.requestNextPageRetry()
        let retryTask = Task {
            await model.loadRequestedNextPage()
        }
        await loader.waitForRequestCount(3)

        #expect(await loader.requests() == [firstRequest, secondRequest, secondRequest])

        await loader.succeed(page(number: 2, total: 41, items: [secondManga]), at: 2)
        await retryTask.value

        #expect(model.query == query)
        #expect(model.state == .content(.init(items: [firstManga, secondManga], pagination: .ready(nextPage: 3))))
    }

    @Test
    func filterOptionsLoadOnceAndRemainIndependentFromPageState() async {
        let loader = ControlledCatalogFilterOptionsLoader()
        let options = CatalogFilterOptions(demographics: ["Seinen"], genres: ["Drama"], themes: ["Psychological"])
        let emptyPage = page(items: [])
        let model = CatalogModel(
            initialState: .empty,
            loadFilterOptions: {
                try await loader.load()
            }
        ) { _ in
            emptyPage
        }

        let loadTask = Task {
            await model.loadFilterOptionsIfNeeded()
        }
        await loader.waitForRequestCount(1)

        #expect(model.filterOptionsState == .loading)
        #expect(model.state == .empty)

        await loader.succeed(options, at: 0)
        await loadTask.value

        #expect(model.filterOptionsState == .content(options))
        #expect(model.state == .empty)

        await model.loadFilterOptionsIfNeeded()
        #expect(await loader.requests() == 1)
    }

    @Test
    func loadedFilterOptionsRetainCurrentQuerySelections() async {
        let loader = ControlledCatalogFilterOptionsLoader()
        let serverOptions = CatalogFilterOptions(demographics: ["Seinen"], genres: ["Drama"], themes: ["Psychological"])
        let emptyPage = page(items: [])
        let model = CatalogModel(
            initialQuery: .advanced(CatalogSearch(genres: ["Mystery"], themes: ["Space"], demographics: ["Josei"])),
            loadFilterOptions: {
                try await loader.load()
            }
        ) { _ in
            emptyPage
        }

        let loadTask = Task {
            await model.loadFilterOptionsIfNeeded()
        }
        await loader.waitForRequestCount(1)
        await loader.succeed(serverOptions, at: 0)
        await loadTask.value

        #expect(
            model.filterOptionsState == .content(
                CatalogFilterOptions(
                    demographics: ["Josei", "Seinen"],
                    genres: ["Drama", "Mystery"],
                    themes: ["Psychological", "Space"]
                )
            )
        )

        model.apply(query: .advanced(CatalogSearch(genres: ["Adventure"])))

        #expect(
            model.filterOptionsState == .content(
                CatalogFilterOptions(
                    demographics: ["Seinen"],
                    genres: ["Adventure", "Drama"],
                    themes: ["Psychological"]
                )
            )
        )
    }

    @Test
    func applyingQueryPreparesExistingFilterOptions() {
        let serverOptions = CatalogFilterOptions(demographics: ["Seinen"], genres: ["Drama"], themes: ["Psychological"])
        let emptyPage = page(items: [])
        let model = CatalogModel(initialFilterOptionsState: .content(serverOptions)) { _ in
            emptyPage
        }

        model.apply(query: .advanced(CatalogSearch(genres: ["Mystery"], themes: ["Space"], demographics: ["Josei"])))

        #expect(
            model.filterOptionsState == .content(
                CatalogFilterOptions(
                    demographics: ["Josei", "Seinen"],
                    genres: ["Drama", "Mystery"],
                    themes: ["Psychological", "Space"]
                )
            )
        )
    }

    @Test
    func filterOptionsFailureRetriesWithoutChangingTheQuery() async {
        let loader = ControlledCatalogFilterOptionsLoader()
        let options = CatalogFilterOptions(demographics: ["Josei"], genres: ["Mystery"], themes: ["Adult Cast"])
        let emptyPage = page(items: [])
        let model = CatalogModel(
            initialState: .empty,
            initialQuery: .best,
            loadFilterOptions: {
                try await loader.load()
            }
        ) { _ in
            emptyPage
        }

        let failedTask = Task {
            await model.loadFilterOptionsIfNeeded()
        }
        await loader.waitForRequestCount(1)
        await loader.fail(CatalogAPIClientError.network(.statusCode(503)), at: 0)
        await failedTask.value

        #expect(model.filterOptionsState == .failure(.network(.statusCode(503))))

        let retryTask = Task {
            await model.retryFilterOptions()
        }
        await loader.waitForRequestCount(2)
        await loader.succeed(options, at: 1)
        await retryTask.value

        #expect(model.query == .best)
        #expect(model.filterOptionsState == .content(options))
        #expect(model.state == .empty)
    }

    @Test
    func cancellingFilterOptionsRestoresIdleWithoutVisibleFailure() async {
        let loader = ControlledCatalogFilterOptionsLoader()
        let emptyPage = page(items: [])
        let model = CatalogModel(
            loadFilterOptions: {
                try await loader.load()
            }
        ) { _ in
            emptyPage
        }

        let loadTask = Task {
            await model.loadFilterOptionsIfNeeded()
        }
        await loader.waitForRequestCount(1)

        loadTask.cancel()
        await loadTask.value

        #expect(await loader.wasCancelled(at: 0))
        #expect(model.filterOptionsState == .idle)
    }

    @Test
    func reenteringFilterOptionsWhilePreviousLoadCancelsStartsFreshRequest() async {
        let options = CatalogFilterOptions(demographics: ["Seinen"], genres: ["Drama"], themes: ["Psychological"])
        let loader = ReentrantCatalogFilterOptionsLoader(options: options)
        let emptyPage = page(items: [])
        let model = CatalogModel(
            loadFilterOptions: {
                try await loader.load()
            }
        ) { _ in
            emptyPage
        }

        let firstTask = Task {
            await model.loadFilterOptionsIfNeeded()
        }
        await loader.waitForRequestCount(1)

        #expect(model.filterOptionsState == .loading)

        await model.loadFilterOptionsIfNeeded()
        firstTask.cancel()
        await firstTask.value

        #expect(await loader.requestCount() == 2)
        #expect(await loader.firstRequestWasCancelled())
        #expect(model.filterOptionsState == .content(options))
    }

    private func makeModel(loader: ControlledCatalogLoader) -> CatalogModel {
        CatalogModel { request in
            try await loader.load(request)
        }
    }

    private func terminalContent(_ items: [Manga]) -> CatalogModel.State {
        .content(.init(items: items, pagination: .end))
    }

    private func advancedQuery() -> CatalogQuery {
        .advanced(
            CatalogSearch(
                matchMode: .contains,
                title: "Frieren",
                authorFirstName: "Kanehito",
                authorLastName: "Yamada",
                genres: ["Adventure"],
                themes: ["Military"],
                demographics: ["Shounen"]
            )
        )
    }

    private func page(
        number: Int64 = 1,
        per: Int64 = 20,
        total: Int64? = nil,
        items: [Manga]
    ) -> CatalogPage {
        CatalogPage(items: items, metadata: .init(page: number, per: per, total: total ?? Int64(items.count)))
    }

    private func manga(id: Manga.ID, title: String) -> Manga {
        Manga(
            id: id,
            title: title,
            titleEnglish: nil,
            titleJapanese: nil,
            synopsis: nil,
            score: 8.5,
            status: .unspecified,
            authors: [],
            demographics: [],
            genres: [],
            themes: [],
            coverURL: nil
        )
    }
}

private actor ReentrantCatalogPageLoader {
    private let subsequentPage: CatalogPage
    private(set) var requests: [CatalogPageRequest] = []
    private var firstContinuation: CheckedContinuation<CatalogPage, any Error>?
    private var firstRequestWaiter: CheckedContinuation<Void, Never>?

    init(subsequentPage: CatalogPage) {
        self.subsequentPage = subsequentPage
    }

    func load(_ request: CatalogPageRequest) async throws -> CatalogPage {
        requests.append(request)
        guard requests.count == 1 else { return subsequentPage }

        // Retain the first completion even after cancellation until the test releases it.
        return try await withCheckedThrowingContinuation { continuation in
            firstContinuation = continuation
            firstRequestWaiter?.resume()
            firstRequestWaiter = nil
        }
    }

    func waitForFirstRequest() async {
        guard requests.isEmpty else { return }

        await withCheckedContinuation { continuation in
            firstRequestWaiter = continuation
        }
    }

    func completeFirstRequest(with result: Result<CatalogPage, any Error>) {
        firstContinuation?.resume(with: result)
        firstContinuation = nil
    }
}

private actor ReentrantCatalogFilterOptionsLoader {
    private struct RequestWaiter {
        let expectedCount: Int
        let continuation: CheckedContinuation<Void, Never>
    }

    private let options: CatalogFilterOptions
    private var count = 0
    private var firstContinuation: CheckedContinuation<CatalogFilterOptions, any Error>?
    private var firstCancelled = false
    private var requestWaiters: [RequestWaiter] = []

    init(options: CatalogFilterOptions) {
        self.options = options
    }

    func load() async throws -> CatalogFilterOptions {
        let requestIndex = count
        count += 1
        resumeSatisfiedRequestWaiters()

        guard requestIndex == 0 else { return options }

        return try await withTaskCancellationHandler {
            try await withCheckedThrowingContinuation { continuation in
                if firstCancelled {
                    continuation.resume(throwing: CancellationError())
                } else {
                    firstContinuation = continuation
                }
            }
        } onCancel: {
            Task {
                await self.cancelFirstRequest()
            }
        }
    }

    func requestCount() -> Int { count }

    func waitForRequestCount(_ expectedCount: Int) async {
        guard count < expectedCount else { return }

        await withCheckedContinuation { continuation in
            requestWaiters.append(RequestWaiter(expectedCount: expectedCount, continuation: continuation))
        }
    }

    func firstRequestWasCancelled() -> Bool { firstCancelled }

    private func cancelFirstRequest() {
        firstCancelled = true
        firstContinuation?.resume(throwing: CancellationError())
        firstContinuation = nil
    }

    private func resumeSatisfiedRequestWaiters() {
        let satisfiedWaiters = requestWaiters.filter {
            count >= $0.expectedCount
        }
        requestWaiters.removeAll {
            count >= $0.expectedCount
        }
        satisfiedWaiters.forEach {
            $0.continuation.resume()
        }
    }
}
