import Foundation
import Synchronization
import Testing
@testable import MangaLibrary

@Suite("Watch callback delivery ordering", .tags(.fast))
struct WatchReadingEventQueueTests {
    @Test(arguments: [false, true])
    func `an earlier activation failure cannot discard subsequently registered content`(
        _ activates: Bool
    ) async throws {
        let queue = WatchReadingEventQueue()
        let entered = AsyncStream<Void>.makeStream()
        let resume = AsyncStream<Void>.makeStream()
        let accepted = Mutex<Data?>(nil)
        let preparation = Mutex((first: true, activated: false))
        let current = Self.context(
            epoch: "22222222-2222-4222-8222-222222222222",
            session: "bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbbb"
        )
        defer {
            entered.continuation.finish()
            resume.continuation.finish()
        }

        try await withThrowingTaskGroup(of: Void.self) { group in
            group.addTask {
                try await queue.run(
                    untilContentDrained: true,
                    prepare: {
                        queue.record(.activated)
                    },
                    checkContentDrain: { identity in
                        let status = preparation.withLock { state in
                            let previous = state
                            state.first = false
                            return previous
                        }
                        if status.first {
                            queue.record(.unavailable)
                        } else if status.activated, let identity {
                            queue.record(.received(current))
                            queue.record(.requestedContentDrained(identity))
                        }
                    },
                    receive: { event in
                        switch event {
                        case .activated:
                            if preparation.withLock({ !$0.activated }) {
                                entered.continuation.yield(())
                                var iterator = resume.stream.makeAsyncIterator()
                                _ = await iterator.next()
                            }
                        case let .received(data):
                            accepted.withLock {
                                $0 = data
                            }
                        case .contentDrained, .requestedContentDrained, .invalidContext, .unavailable:
                            break
                        }
                    }
                )
            }
            var started = entered.stream.makeAsyncIterator()
            _ = await started.next()
            preparation.withLock {
                $0.activated = activates
            }
            if activates {
                queue.record(.activated)
            }
            queue.record(.received(current))
            resume.continuation.yield(())
            try await group.waitForAll()
        }

        let data = try #require(accepted.withLock { $0 })
        let snapshot = try ReadingSnapshotCodec.decode(data)
        #expect(snapshot.publicationGeneration.uuidString.lowercased() == "22222222-2222-4222-8222-222222222222")
    }

    @Test
    func `a finite drain persists content registered while its earlier receive is suspended`() async throws {
        let first = Self.context(
            epoch: "11111111-1111-4111-8111-111111111111",
            session: "aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa"
        )
        let second = Self.context(
            epoch: "22222222-2222-4222-8222-222222222222",
            session: "bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbbb"
        )
        let current = Mutex(first)
        let stored = Mutex<Data?>(nil)
        let storage = WatchReadingSnapshotStorage(
            read: { stored.withLock { $0 } },
            replace: { data in
                stored.withLock {
                    $0 = data
                }
            },
            discard: {
                stored.withLock {
                    $0 = nil
                }
            }
        )
        let receiver = WatchReadingSnapshotReceiver(storage: storage)
        let entered = AsyncStream<Void>.makeStream()
        let resume = AsyncStream<Void>.makeStream()
        let queue = WatchReadingEventQueue()
        defer {
            entered.continuation.finish()
            resume.continuation.finish()
        }

        try await withThrowingTaskGroup(of: Void.self) { group in
            group.addTask {
                try await queue.run(
                    untilContentDrained: true,
                    prepare: {},
                    checkContentDrain: { identity in
                        guard let identity else { return }
                        queue.record(.received(current.withLock { $0 }))
                        queue.record(.requestedContentDrained(identity))
                    },
                    receive: { event in
                        guard case let .received(data) = event else { return }
                        _ = await receiver.receive(data)
                        if data == first {
                            entered.continuation.yield(())
                            var iterator = resume.stream.makeAsyncIterator()
                            _ = await iterator.next()
                        }
                    }
                )
            }
            var started = entered.stream.makeAsyncIterator()
            _ = await started.next()
            current.withLock {
                $0 = second
            }
            queue.record(.received(second))
            resume.continuation.yield(())
            try await group.waitForAll()
        }

        let relaunched = WatchReadingSnapshotReceiver(storage: storage)
        let result = await relaunched.restore()
        guard case let .snapshot(snapshot) = result else {
            Issue.record("The finite lease must persist all content accepted before its completion")
            return
        }
        #expect(snapshot.publicationGeneration.uuidString.lowercased() == "22222222-2222-4222-8222-222222222222")
    }

    @Test
    func `a finite consumer waits for its own drain instead of an older terminal`() async throws {
        let queue = WatchReadingEventQueue()
        let accepted = Mutex<Data?>(nil)
        let current = Self.context(
            epoch: "22222222-2222-4222-8222-222222222222",
            session: "bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbbb"
        )

        try await queue.run(
            untilContentDrained: true,
            prepare: {
                queue.record(.contentDrained)
            },
            checkContentDrain: { identity in
                guard let identity else { return }
                queue.record(.received(current))
                queue.record(.requestedContentDrained(identity))
            },
            receive: { event in
                if case let .received(data) = event {
                    accepted.withLock {
                        $0 = data
                    }
                }
            }
        )

        let data = try #require(accepted.withLock { $0 })
        let snapshot = try ReadingSnapshotCodec.decode(data)
        #expect(snapshot.publicationGeneration.uuidString.lowercased() == "22222222-2222-4222-8222-222222222222")
    }

    @Test
    func `a queued drain cannot replay a later epoch ahead of earlier callbacks`() async throws {
        let cache = Mutex<Data?>(nil)
        let storage = WatchReadingSnapshotStorage(
            read: { cache.withLock { $0 } },
            replace: { bytes in
                cache.withLock {
                    $0 = bytes
                }
            },
            discard: {
                cache.withLock {
                    $0 = nil
                }
            }
        )
        let receiver = WatchReadingSnapshotReceiver(storage: storage)
        let queue = WatchReadingEventQueue()
        let entered = AsyncStream<Void>.makeStream()
        let resume = AsyncStream<Void>.makeStream()
        let completed = AsyncStream<Void>.makeStream()
        defer {
            entered.continuation.finish()
            resume.continuation.finish()
            completed.continuation.finish()
        }
        let first = Self.context(
            epoch: "11111111-1111-4111-8111-111111111111",
            session: "aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa"
        )
        let second = Self.context(
            epoch: "22222222-2222-4222-8222-222222222222",
            session: "bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbbb"
        )

        try await withThrowingTaskGroup(of: Void.self) { group in
            group.addTask {
                try await queue.run(
                    prepare: {
                        queue.record(.activated)
                    },
                    checkContentDrain: { _ in }
                ) { event in
                    switch event {
                    case .activated:
                        entered.continuation.yield(())
                        var iterator = resume.stream.makeAsyncIterator()
                        _ = await iterator.next()
                    case let .received(data):
                        _ = await receiver.receive(data)
                    case .unavailable:
                        completed.continuation.yield(())
                    case .invalidContext, .contentDrained, .requestedContentDrained:
                        break
                    }
                }
            }
            var started = entered.stream.makeAsyncIterator()
            _ = await started.next()
            queue.record(.contentDrained)
            queue.record(.received(first))
            queue.record(.received(second))
            queue.record(.unavailable)
            resume.continuation.yield(())
            var drained = completed.stream.makeAsyncIterator()
            _ = await drained.next()
            group.cancelAll()
            do {
                try await group.waitForAll()
            } catch is CancellationError {
            }
        }

        let relaunched = WatchReadingSnapshotReceiver(storage: storage)
        let result = await relaunched.restore()
        guard case let .snapshot(snapshot) = result else {
            Issue.record("Both compatible contexts must leave the second epoch cached")
            return
        }
        #expect(snapshot.publicationGeneration.uuidString.lowercased() == "22222222-2222-4222-8222-222222222222")
        #expect(snapshot.sessionGeneration?.uuidString.lowercased() == "bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbbb")
    }

    private static func context(epoch: String, session: String) -> Data {
        Data("""
        {"formatVersion":1,"publicationGeneration":"\(epoch)","revision":1,
        "sessionGeneration":"\(session)","state":"empty","generatedAt":"2026-09-06T00:00:00.000Z",
        "totalEligibleCount":0,"items":[]}
        """.utf8)
    }
}
