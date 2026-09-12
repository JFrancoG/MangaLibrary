//
//  ControlledCatalogFilterOptionsLoader.swift
//  MangaLibraryTests
//

@testable import MangaLibrary

actor ControlledCatalogFilterOptionsLoader {
    private struct RequestWaiter {
        let expectedCount: Int
        let continuation: CheckedContinuation<Void, Never>
    }

    private var requestCount = 0
    private var continuations: [Int: CheckedContinuation<CatalogFilterOptions, any Error>] = [:]
    private var cancelledRequestIndices: Set<Int> = []
    private var requestWaiters: [RequestWaiter] = []

    func load() async throws -> CatalogFilterOptions {
        let requestIndex = requestCount
        requestCount += 1
        resumeSatisfiedRequestWaiters()

        return try await withTaskCancellationHandler {
            try await withCheckedThrowingContinuation { continuation in
                if cancelledRequestIndices.contains(requestIndex) {
                    continuation.resume(throwing: CancellationError())
                } else {
                    continuations[requestIndex] = continuation
                }
            }
        } onCancel: {
            Task {
                await self.cancelRequest(at: requestIndex)
            }
        }
    }

    func requests() -> Int { requestCount }

    func waitForRequestCount(_ expectedCount: Int) async {
        guard requestCount < expectedCount else { return }

        await withCheckedContinuation { continuation in
            requestWaiters.append(RequestWaiter(expectedCount: expectedCount, continuation: continuation))
        }
    }

    func succeed(_ options: CatalogFilterOptions, at requestIndex: Int) {
        continuations.removeValue(forKey: requestIndex)?.resume(returning: options)
    }

    func fail(_ error: any Error, at requestIndex: Int) {
        continuations.removeValue(forKey: requestIndex)?.resume(throwing: error)
    }

    func wasCancelled(at requestIndex: Int) -> Bool { cancelledRequestIndices.contains(requestIndex) }

    private func cancelRequest(at requestIndex: Int) {
        cancelledRequestIndices.insert(requestIndex)
        continuations.removeValue(forKey: requestIndex)?.resume(throwing: CancellationError())
    }

    private func resumeSatisfiedRequestWaiters() {
        let satisfiedWaiters = requestWaiters.filter {
            requestCount >= $0.expectedCount
        }
        requestWaiters.removeAll {
            requestCount >= $0.expectedCount
        }
        satisfiedWaiters.forEach {
            $0.continuation.resume()
        }
    }
}
