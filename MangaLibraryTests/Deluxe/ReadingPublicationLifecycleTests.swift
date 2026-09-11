import Foundation
import Synchronization
import Testing
@testable import MangaLibrary

@Suite("Scene-owned reading publication lifecycle", .tags(.fast))
@MainActor
struct ReadingPublicationLifecycleTests {
    @Test
    func `a normal consumer lifetime runs once without scheduling another lifetime`() async {
        let calls = Mutex(0)
        let identities = ReadingLifecycleIdentities()
        let lifecycle = ReadingPublicationLifecycle(
            runPipeline: {
                calls.withLock {
                    $0 += 1
                }
            },
            makeIdentity: identities.next
        )
        let initialWake = lifecycle.wakeID

        await lifecycle.run()

        #expect(calls.withLock { $0 } == 1)
        #expect(lifecycle.failure == nil)
        #expect(lifecycle.wakeID == initialWake)
    }

    @Test
    func `failed retirement preserves its authority and waits for an explicit retry`() async throws {
        let calls = Mutex(0)
        let identities = ReadingLifecycleIdentities()
        let authority = Self.authority
        let lifecycle = ReadingPublicationLifecycle(
            runPipeline: {
                let attempt = calls.withLock {
                    $0 += 1
                    return $0
                }
                if attempt == 1 {
                    throw ReadingPublicationSessionReconciliationError(
                        authority: authority,
                        underlyingError: SessionControllerError.persistenceUnavailable
                    )
                }
            },
            makeIdentity: identities.next
        )
        let initialWake = lifecycle.wakeID

        await lifecycle.run()

        let failure = try #require(lifecycle.failure)
        #expect(failure.authority == authority)
        #expect(failure.underlyingError as? SessionControllerError == .persistenceUnavailable)
        #expect(lifecycle.wakeID == initialWake)
        await lifecycle.run()
        #expect(calls.withLock { $0 } == 1)
        #expect(lifecycle.failure?.identity == failure.identity)

        lifecycle.retry()

        #expect(lifecycle.failure == nil)
        #expect(lifecycle.wakeID != initialWake)
        await lifecycle.run()
        #expect(calls.withLock { $0 } == 2)
        #expect(lifecycle.failure == nil)
    }

    @Test
    func `an unexpected consumer failure stays visible without guessing a session authority`() async throws {
        let calls = Mutex(0)
        let lifecycle = ReadingPublicationLifecycle(runPipeline: {
            calls.withLock {
                $0 += 1
            }
            throw ReadingPublicationPipelineError.consumerAlreadyRunning
        })
        let initialWake = lifecycle.wakeID

        await lifecycle.run()
        await lifecycle.run()

        let failure = try #require(lifecycle.failure)
        #expect(failure.authority == nil)
        #expect(failure.underlyingError as? ReadingPublicationPipelineError == .consumerAlreadyRunning)
        #expect(calls.withLock { $0 } == 1)
        #expect(lifecycle.wakeID == initialWake)
    }

    @Test
    func `another scene cannot take ownership until the cancelled consumer has drained`() async throws {
        let calls = Mutex(0)
        let signals = AsyncStream<ReadingLifecycleSignal>.makeStream()
        defer { signals.continuation.finish() }
        let suspension = ReadingLifecycleSuspension()
        let identities = ReadingLifecycleIdentities()
        let lifecycle = ReadingPublicationLifecycle(
            runPipeline: {
                let attempt = calls.withLock {
                    $0 += 1
                    return $0
                }
                if attempt == 1 {
                    signals.continuation.yield(.started)
                    await suspension.wait()
                }
                try Task.checkCancellation()
            },
            makeIdentity: identities.next
        )
        let initialWake = lifecycle.wakeID

        try await withThrowingTaskGroup(of: Void.self) { group in
            defer {
                suspension.release()
                group.cancelAll()
            }
            group.addTask {
                await lifecycle.run()
                signals.continuation.yield(.finished)
            }
            var iterator = signals.stream.makeAsyncIterator()
            try #require(await iterator.next() == .started)

            group.cancelAll()
            await lifecycle.run()
            lifecycle.retry()
            #expect(calls.withLock { $0 } == 1)
            #expect(lifecycle.wakeID == initialWake)
            suspension.release()
            try await group.waitForAll()
        }

        #expect(lifecycle.failure == nil)
        #expect(lifecycle.wakeID != initialWake)
        await lifecycle.run()
        #expect(calls.withLock { $0 } == 2)
    }

    @Test
    func `an already cancelled scene neither starts the consumer nor wakes other scenes`() async {
        let calls = Mutex(0)
        let lifecycle = ReadingPublicationLifecycle(
            runPipeline: {
                calls.withLock {
                    $0 += 1
                }
            }
        )
        let initialWake = lifecycle.wakeID

        await withTaskGroup(of: Void.self) { group in
            group.cancelAll()
            group.addTask {
                await lifecycle.run()
            }
            await group.waitForAll()
        }

        #expect(calls.withLock { $0 } == 0)
        #expect(lifecycle.wakeID == initialWake)
        #expect(lifecycle.failure == nil)
    }

    @Test
    func `a retirement failure during cancellation remains visible without an automatic wake`() async throws {
        let signals = AsyncStream<ReadingLifecycleSignal>.makeStream()
        defer { signals.continuation.finish() }
        let suspension = ReadingLifecycleSuspension()
        let authority = Self.authority
        let lifecycle = ReadingPublicationLifecycle(runPipeline: {
            signals.continuation.yield(.started)
            await suspension.wait()
            throw ReadingPublicationSessionReconciliationError(
                authority: authority,
                underlyingError: SessionControllerError.persistenceUnavailable
            )
        })
        let initialWake = lifecycle.wakeID

        try await withThrowingTaskGroup(of: Void.self) { group in
            defer {
                suspension.release()
                group.cancelAll()
            }
            group.addTask {
                await lifecycle.run()
                signals.continuation.yield(.finished)
            }
            var iterator = signals.stream.makeAsyncIterator()
            try #require(await iterator.next() == .started)
            group.cancelAll()
            suspension.release()
            try await group.waitForAll()
        }

        let failure = try #require(lifecycle.failure)
        #expect(failure.authority == authority)
        #expect(failure.underlyingError as? SessionControllerError == .persistenceUnavailable)
        #expect(lifecycle.wakeID == initialWake)
    }

    private static let authority = SessionAuthority(
        userID: UUID(uuid: (0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 1)),
        generation: UUID(uuid: (0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 2))
    )
}

private enum ReadingLifecycleSignal {
    case started
    case finished
}

private final class ReadingLifecycleIdentities: Sendable {
    private let nextValue = Mutex<UInt8>(0)

    func next() -> UUID {
        let value = nextValue.withLock {
            $0 += 1
            return $0
        }
        return UUID(uuid: (0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, value))
    }
}

private final class ReadingLifecycleSuspension: Sendable {
    private struct State {
        var continuation: CheckedContinuation<Void, Never>?
        var released = false
    }

    private let state = Mutex(State())

    func wait() async {
        await withCheckedContinuation { continuation in
            let released = state.withLock { state in
                if state.released {
                    return true
                }
                state.continuation = continuation
                return false
            }
            if released {
                continuation.resume()
            }
        }
    }

    func release() {
        let continuation = state.withLock { state in
            state.released = true
            let continuation = state.continuation
            state.continuation = nil
            return continuation
        }
        continuation?.resume()
    }
}
