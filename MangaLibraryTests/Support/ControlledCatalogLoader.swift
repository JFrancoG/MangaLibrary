//
//  ControlledCatalogLoader.swift
//  MangaLibraryTests
//

import Foundation
@testable import MangaLibrary

actor ControlledCatalogLoader {
    private struct RequestWaiter {
        let expectedCount: Int
        let continuation: CheckedContinuation<Void, Never>
    }

    private struct CancellationWaiter {
        let requestIndex: Int
        let continuation: CheckedContinuation<Void, Never>
    }

    private var recordedRequests: [CatalogPageRequest] = []
    private var continuations: [Int: CheckedContinuation<CatalogPage, any Error>] = [:]
    private var cancelledRequestIndices: Set<Int> = []
    private var requestWaiters: [RequestWaiter] = []
    private var cancellationWaiters: [CancellationWaiter] = []

    func load(_ request: CatalogPageRequest) async throws -> CatalogPage {
        let requestIndex = recordedRequests.count
        recordedRequests.append(request)
        resumeSatisfiedRequestWaiters()

        return try await withTaskCancellationHandler {
            try await withCheckedThrowingContinuation { continuation in
                install(continuation, at: requestIndex)
            }
        } onCancel: {
            Task {
                await self.cancelRequest(at: requestIndex)
            }
        }
    }

    func requests() -> [CatalogPageRequest] {
        recordedRequests
    }

    func waitForRequestCount(_ expectedCount: Int) async {
        guard recordedRequests.count < expectedCount else { return }

        await withCheckedContinuation { continuation in
            requestWaiters.append(RequestWaiter(expectedCount: expectedCount, continuation: continuation))
        }
    }

    func succeed(_ page: CatalogPage, at requestIndex: Int) {
        continuations.removeValue(forKey: requestIndex)?.resume(returning: page)
    }

    func fail(_ error: any Error, at requestIndex: Int) {
        continuations.removeValue(forKey: requestIndex)?.resume(throwing: error)
    }

    func wasCancelled(at requestIndex: Int) -> Bool {
        cancelledRequestIndices.contains(requestIndex)
    }

    func waitForCancellation(at requestIndex: Int) async {
        guard !cancelledRequestIndices.contains(requestIndex) else { return }

        await withCheckedContinuation { continuation in
            cancellationWaiters.append(CancellationWaiter(requestIndex: requestIndex, continuation: continuation))
        }
    }

    private func install(_ continuation: CheckedContinuation<CatalogPage, any Error>, at requestIndex: Int) {
        if cancelledRequestIndices.contains(requestIndex) {
            continuation.resume(throwing: CancellationError())
        } else {
            continuations[requestIndex] = continuation
        }
    }

    private func cancelRequest(at requestIndex: Int) {
        cancelledRequestIndices.insert(requestIndex)
        continuations.removeValue(forKey: requestIndex)?.resume(throwing: CancellationError())
        resumeSatisfiedCancellationWaiters()
    }

    private func resumeSatisfiedRequestWaiters() {
        let satisfiedWaiters = requestWaiters.filter {
            recordedRequests.count >= $0.expectedCount
        }
        requestWaiters.removeAll {
            recordedRequests.count >= $0.expectedCount
        }
        satisfiedWaiters.forEach { $0.continuation.resume() }
    }

    private func resumeSatisfiedCancellationWaiters() {
        let satisfiedWaiters = cancellationWaiters.filter {
            cancelledRequestIndices.contains($0.requestIndex)
        }
        cancellationWaiters.removeAll {
            cancelledRequestIndices.contains($0.requestIndex)
        }
        satisfiedWaiters.forEach { $0.continuation.resume() }
    }
}
