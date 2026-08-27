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
        await loader.fail(
            CatalogAPIClientError.network(.transport(.notConnectedToInternet)),
            at: 0
        )
        await initialTask.value

        #expect(
            model.state
                == .failure(.network(.transport(.notConnectedToInternet)))
        )

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

        await loader.fail(
            CatalogAPIClientError.network(.transport(.timedOut)),
            at: 0
        )
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
        await loader.succeed(
            page(
                number: 1,
                total: 40,
                items: [firstManga, selectedManga]
            ),
            at: 0
        )
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
                items: [
                    manga(id: selectedManga.id, title: "Changed duplicate"),
                    appendedManga
                ]
            ),
            at: 1
        )
        await nextPageTask.value

        #expect(
            model.state == .content(
                .init(
                    items: [firstManga, selectedManga, appendedManga],
                    pagination: .end
                )
            )
        )
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
        await loader.succeed(
            page(number: 1, total: 1, items: [onlyManga]),
            at: 0
        )
        await initialTask.value

        model.requestNextPageIfNeeded(after: onlyManga.id)
        await model.loadRequestedNextPage()

        #expect(model.requestedNextPage == nil)
        #expect(await loader.requests().count == 1)
        #expect(
            model.state == .content(
                .init(items: [onlyManga], pagination: .end)
            )
        )
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
        await loader.succeed(
            page(number: 1, total: 41, items: [firstManga]),
            at: 0
        )
        await initialTask.value

        model.requestNextPageIfNeeded(after: firstManga.id)
        let nextPageTask = Task {
            await model.loadRequestedNextPage()
        }
        await loader.waitForRequestCount(2)
        await loader.succeed(
            page(number: 2, total: 41, items: []),
            at: 1
        )
        await nextPageTask.value

        #expect(
            model.state == .content(
                .init(items: [firstManga], pagination: .end)
            )
        )

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
        await loader.succeed(
            page(number: 1, total: 41, items: [firstManga]),
            at: 0
        )
        await initialTask.value

        model.requestNextPageIfNeeded(after: firstManga.id)
        let failedTask = Task {
            await model.loadRequestedNextPage()
        }
        await loader.waitForRequestCount(2)
        await loader.fail(
            CatalogAPIClientError.network(.transport(.notConnectedToInternet)),
            at: 1
        )
        await failedTask.value

        #expect(
            model.state == .content(
                .init(
                    items: [firstManga],
                    pagination: .failure(
                        page: 2,
                        reason: .network(.transport(.notConnectedToInternet))
                    )
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
        await loader.succeed(
            page(number: 2, total: 41, items: [secondManga]),
            at: 2
        )
        await retryTask.value

        #expect(
            model.state == .content(
                .init(
                    items: [firstManga, secondManga],
                    pagination: .ready(nextPage: 3)
                )
            )
        )
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
        await loader.succeed(
            page(number: 1, total: 41, items: [firstManga]),
            at: 0
        )
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
        #expect(
            model.state == .content(
                .init(
                    items: [firstManga],
                    pagination: .ready(nextPage: 2)
                )
            )
        )
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
        await loader.succeed(
            page(number: 1, total: 41, items: [staleManga]),
            at: 0
        )
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
        await loader.succeed(
            page(number: 1, total: 1, items: [currentManga]),
            at: 2
        )
        await reloadTask.value

        await loader.succeed(
            page(number: 2, total: 41, items: [staleManga]),
            at: 1
        )
        await staleTask.value

        #expect(
            model.state == .content(
                .init(items: [currentManga], pagination: .end)
            )
        )
        #expect(model.requestedNextPage == nil)
    }

    private func makeModel(loader: ControlledCatalogLoader) -> CatalogModel {
        CatalogModel { request in
            try await loader.load(request)
        }
    }

    private func terminalContent(_ items: [Manga]) -> CatalogModel.State {
        .content(.init(items: items, pagination: .end))
    }

    private func page(
        number: Int64 = 1,
        per: Int64 = 20,
        total: Int64? = nil,
        items: [Manga]
    ) -> CatalogPage {
        CatalogPage(
            items: items,
            metadata: .init(
                page: number,
                per: per,
                total: total ?? Int64(items.count)
            )
        )
    }

    private func manga(id: Manga.ID, title: String) -> Manga {
        Manga(
            id: id,
            title: title,
            titleEnglish: nil,
            titleJapanese: nil,
            synopsis: nil,
            score: 8.5,
            coverURL: nil
        )
    }
}
