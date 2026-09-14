import SwiftData
import Testing
@testable import MangaLibrary

@Suite("Application startup", .tags(.integration), .timeLimit(.minutes(1)))
@MainActor
struct AppStartupModelTests {
    @Test
    func `Storage failure waits for explicit retry and never constructs app resources`() async {
        let store = UnavailableStartupStore()
        var compositions = 0
        let model = AppStartupModel(openStore: {
            try await store.open()
        }) { container in
            compositions += 1
            return AppStartupTestSupport.runtime(modelContainer: container)
        }

        await model.startIfNeeded()

        guard case .unavailable = model.state else {
            Issue.record("Opening failure must remain recoverable without a runtime.")
            return
        }
        #expect(compositions == 0)
        #expect(await store.openings == 1)

        await model.startIfNeeded()
        #expect(await store.openings == 1)

        await model.retry()

        guard case .unavailable = model.state else {
            Issue.record("A repeated storage failure must remain recoverable.")
            return
        }
        await model.startIfNeeded()
        #expect(await store.openings == 2)
        #expect(compositions == 0)
    }

    @Test
    func `Window cancellation and repeated intents preserve one shared opening and runtime`() async throws {
        let store = SuspendedStartupStore()
        var compositions = 0
        let model = AppStartupModel(openStore: {
            try await store.open()
        }) { container in
            compositions += 1
            return AppStartupTestSupport.runtime(modelContainer: container)
        }
        let firstWindow = Task {
            await model.startIfNeeded()
        }
        await store.waitUntilOpening()

        guard case .opening = model.state else {
            await store.release()
            await firstWindow.value
            Issue.record("The shell must wait while its store opens.")
            return
        }
        #expect(compositions == 0)
        await model.startIfNeeded()
        await model.retry()
        firstWindow.cancel()
        await store.release()
        await firstWindow.value

        guard case let .ready(runtime) = model.state else {
            Issue.record("Closing a window must not cancel the app's shared opening.")
            return
        }
        #expect(await store.openings == 1)
        #expect(await store.wasCancelled == false)
        #expect(compositions == 1)

        await model.startIfNeeded()
        await model.retry()

        guard case let .ready(retained) = model.state else {
            Issue.record("A ready app must keep its runtime.")
            return
        }
        #expect(retained.modelContainer === runtime.modelContainer)
        #expect(retained.accountModel === runtime.accountModel)
        #expect(await store.openings == 1)
        #expect(compositions == 1)
    }
}

private actor UnavailableStartupStore {
    enum Failure: Error {
        case accessUnavailable
    }

    private(set) var openings = 0

    func open() throws -> ModelContainer {
        openings += 1
        throw Failure.accessUnavailable
    }
}

private actor SuspendedStartupStore {
    private(set) var openings = 0
    private(set) var wasCancelled = false
    private var opening: CheckedContinuation<Void, Never>?
    private var observer: CheckedContinuation<Void, Never>?

    func open() async throws -> ModelContainer {
        openings += 1
        await withCheckedContinuation { continuation in
            opening = continuation
            observer?.resume()
            observer = nil
        }
        wasCancelled = Task.isCancelled
        try Task.checkCancellation()
        return try MangaLibrarySchema.makeContainer(isStoredInMemoryOnly: true)
    }

    func waitUntilOpening() async {
        guard opening == nil else { return }
        await withCheckedContinuation { continuation in
            observer = continuation
        }
    }

    func release() {
        opening?.resume()
        opening = nil
    }
}
