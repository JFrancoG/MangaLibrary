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

        #expect(model.state == .content(expectedPage.items))
    }

    @Test
    func emptyInitialPageProducesEmptyState() async {
        let loader = ControlledCatalogLoader()
        let model = makeModel(loader: loader)
        let emptyPage = page(items: [])

        let loadTask = Task {
            await model.loadIfNeeded()
        }
        await loader.waitForRequestCount(1)
        await loader.succeed(emptyPage, at: 0)
        await loadTask.value

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
        await loader.fail(TestFailure.offline, at: 0)
        await initialTask.value

        #expect(model.state == .failure(.unavailable))

        let retryTask = Task {
            await model.retry()
        }
        await loader.waitForRequestCount(2)

        #expect(await loader.requests() == [expectedRequest, expectedRequest])

        await loader.succeed(recoveredPage, at: 1)
        await retryTask.value

        #expect(model.state == .content(recoveredPage.items))
    }

    @Test
    func contractDriftRemainsObservableInFailureState() async {
        let loader = ControlledCatalogLoader()
        let model = makeModel(loader: loader)

        let loadTask = Task {
            await model.loadIfNeeded()
        }
        await loader.waitForRequestCount(1)
        await loader.fail(CatalogAPIClientError.contractDrift, at: 0)
        await loadTask.value

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
        #expect(model.state == .content(currentPage.items))

        await loader.succeed(stalePage, at: 0)
        await staleTask.value

        #expect(model.state == .content(currentPage.items))
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
        #expect(model.state == .content(currentPage.items))

        await loader.fail(TestFailure.offline, at: 0)
        await staleTask.value

        #expect(model.state == .content(currentPage.items))
    }

    @Test
    func loadIfNeededDoesNotReloadExistingContent() async {
        let loader = ControlledCatalogLoader()
        let model = makeModel(loader: loader)
        let firstPage = page(items: [manga(id: 5, title: "Pluto")])

        let initialTask = Task {
            await model.loadIfNeeded()
        }
        await loader.waitForRequestCount(1)
        await loader.succeed(firstPage, at: 0)
        await initialTask.value

        await model.loadIfNeeded()

        #expect(await loader.requests().count == 1)
        #expect(model.state == .content(firstPage.items))
    }

    @Test
    func detailSelectionResolvesFromTheLoadedIdentity() async {
        let loader = ControlledCatalogLoader()
        let model = makeModel(loader: loader)
        let firstManga = manga(id: 6, title: "20th Century Boys")
        let secondManga = manga(id: 7, title: "Billy Bat")
        let loadedPage = page(items: [firstManga, secondManga])

        let loadTask = Task {
            await model.loadIfNeeded()
        }
        await loader.waitForRequestCount(1)
        await loader.succeed(loadedPage, at: 0)
        await loadTask.value

        model.selectedMangaID = secondManga.id

        #expect(model.selectedManga == secondManga)

        model.selectedMangaID = 999

        #expect(model.selectedManga == nil)
        #expect(await loader.requests().count == 1)
    }

    private func makeModel(loader: ControlledCatalogLoader) -> CatalogModel {
        CatalogModel { request in
            try await loader.load(request)
        }
    }

    private func page(items: [Manga]) -> CatalogPage {
        CatalogPage(
            items: items,
            metadata: .init(
                page: 1,
                per: 20,
                total: Int64(items.count)
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

private enum TestFailure: Error {
    case offline
}
