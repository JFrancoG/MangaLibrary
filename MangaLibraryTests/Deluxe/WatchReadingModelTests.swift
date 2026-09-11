import Foundation
import Synchronization
import Testing
@testable import MangaLibrary

@Suite("Watch reading presentation and background lifecycle", .tags(.fast))
struct WatchReadingModelTests {
    @Test @MainActor
    func `activation reconciles the latest redaction before exposing an older disk cache`() async {
        let cache = Cache()
        let previous = WatchReadingSnapshotReceiver(storage: cache.storage)
        _ = await previous.receive(Self.content)
        let probe = Probe()
        let model = WatchReadingModel(
            receiver: WatchReadingSnapshotReceiver(storage: cache.storage),
            connection: .init(
                run: { _, receive in
                    await receive(.activated)
                    await probe.inspectPresentation()
                    await receive(.received(Self.redaction))
                    await receive(.contentDrained)
                },
                requestContentDrain: { _ in }
            )
        )
        probe.model = model

        await model.handleBackground()

        #expect(model.snapshot?.state == .redacted)
        #expect(!probe.observedPreviousContent)
        let restored = await WatchReadingSnapshotReceiver(storage: cache.storage).restore()
        if case .snapshot(let value) = restored {
            #expect(value.state == .redacted)
        } else {
            Issue.record("The received redaction must survive relaunch")
        }
    }

    @Test @MainActor
    func `temporary activation failure preserves received content while identifying a refresh problem`() async {
        let cache = Cache()
        let model = WatchReadingModel(
            receiver: WatchReadingSnapshotReceiver(storage: cache.storage),
            connection: .init(
                run: { _, receive in
                    await receive(.received(Self.content))
                    await receive(.unavailable)
                },
                requestContentDrain: { _ in }
            )
        )

        await model.handleBackground()

        #expect(model.snapshot?.items.map(\.mangaID) == [20])
        #expect(model.isTemporarilyUnavailable)
    }

    @Test @MainActor
    func `a cold launch with a temporary activation failure preserves the last compatible offline cache`() async {
        let cache = Cache()
        _ = await WatchReadingSnapshotReceiver(storage: cache.storage).receive(Self.content)
        let model = WatchReadingModel(
            receiver: WatchReadingSnapshotReceiver(storage: cache.storage),
            connection: .init(
                run: { _, receive in
                    await receive(.unavailable)
                },
                requestContentDrain: { _ in }
            )
        )

        await model.handleBackground()

        #expect(model.snapshot?.items.map(\.mangaID) == [20])
        #expect(model.isTemporarilyUnavailable)
    }

    @Test @MainActor
    func `invalid context framing hides an accepted cache instead of retaining readable data`() async {
        let cache = Cache()
        let model = WatchReadingModel(
            receiver: WatchReadingSnapshotReceiver(storage: cache.storage),
            connection: .init(
                run: { _, receive in
                    await receive(.received(Self.content))
                    await receive(.invalidContext)
                },
                requestContentDrain: { _ in }
            )
        )

        await model.handleBackground()

        #expect(model.snapshot == nil)
        let relaunched = WatchReadingSnapshotReceiver(storage: cache.storage)
        let restored = await relaunched.restore()
        let repeatedContent = await relaunched.receive(Self.content)
        #expect(restored == .unavailable)
        #expect(repeatedContent == .unavailable)
    }

    @Test @MainActor
    func `a background wake joins the running consumer and finishes only after received content is drained`() async {
        let cache = Cache()
        let transport = Transport()
        let model = WatchReadingModel(
            receiver: WatchReadingSnapshotReceiver(storage: cache.storage),
            connection: .init(
                run: { untilDrained, receive in
                    try await transport.run(untilDrained: untilDrained, receive: receive)
                },
                requestContentDrain: { identity in
                    transport.requestedIdentity.withLock {
                        $0 = identity
                    }
                    transport.signals.continuation.yield(.drainRequested)
                }
            )
        )

        await withTaskGroup(of: Void.self) { group in
            group.addTask {
                await model.run()
                transport.signals.continuation.yield(.foregroundFinished)
            }
            var signals = transport.signals.stream.makeAsyncIterator()
            let started = await signals.next()
            #expect(started == .started)
            guard started == .started else {
                group.cancelAll()
                return
            }
            group.addTask {
                await model.handleBackground()
                transport.signals.continuation.yield(.backgroundFinished)
            }
            let request = await signals.next()
            #expect(request == .drainRequested)
            guard request == .drainRequested else {
                group.cancelAll()
                return
            }
            transport.events.continuation.yield(.received(Self.content))
            guard let identity = transport.requestedIdentity.withLock({ $0 }) else {
                Issue.record("The existing consumer must receive this background task's drain request")
                group.cancelAll()
                return
            }
            transport.events.continuation.yield(.requestedContentDrained(identity))
            let completion = await signals.next()
            #expect(completion == .backgroundFinished)
            #expect(model.snapshot?.items.map(\.mangaID) == [20])
            #expect(transport.modes.withLock { $0 } == [false])
            group.cancelAll()
        }
    }

    @Test @MainActor
    func `a background waiter acquires another lease if the previous consumer finishes before its requested drain`() async {
        let cache = Cache()
        let leases = Mutex<Int>(0)
        let release = AsyncStream<Void>.makeStream(bufferingPolicy: .bufferingNewest(1))
        let signals = AsyncStream<Transport.Signal>.makeStream(bufferingPolicy: .unbounded)
        let model = WatchReadingModel(
            receiver: WatchReadingSnapshotReceiver(storage: cache.storage),
            connection: .init(
                run: { _, receive in
                    let lease = leases.withLock { value in
                        value += 1
                        return value
                    }
                    if lease == 1 {
                        signals.continuation.yield(.started)
                        for await _ in release.stream {
                        }
                    } else {
                        await receive(.received(Self.content))
                        await receive(.contentDrained)
                    }
                },
                requestContentDrain: { _ in
                    signals.continuation.yield(.drainRequested)
                }
            )
        )

        await withTaskGroup(of: Void.self) { group in
            group.addTask {
                await model.handleBackground()
            }
            var events = signals.stream.makeAsyncIterator()
            let first = await events.next()
            #expect(first == .started)
            group.addTask {
                await model.handleBackground()
            }
            let requested = await events.next()
            #expect(requested == .drainRequested)
            release.continuation.finish()
        }

        #expect(leases.withLock { $0 } == 2)
        #expect(model.snapshot?.items.map(\.mangaID) == [20])
    }

    @MainActor
    private final class Probe {
        weak var model: WatchReadingModel?
        var observedPreviousContent = false

        func inspectPresentation() {
            observedPreviousContent = model?.snapshot?.state == .content
        }
    }

    private final class Cache: Sendable {
        private let bytes = Mutex<Data?>(nil)

        var storage: WatchReadingSnapshotStorage {
            WatchReadingSnapshotStorage(
                read: { self.bytes.withLock { $0 } },
                replace: { data in
                    self.bytes.withLock {
                        $0 = data
                    }
                },
                discard: {
                    self.bytes.withLock {
                        $0 = nil
                    }
                }
            )
        }
    }

    private final class Transport: Sendable {
        enum Signal: Equatable {
            case started
            case foregroundFinished
            case backgroundFinished
            case drainRequested
        }

        let signals = AsyncStream<Signal>.makeStream(bufferingPolicy: .unbounded)
        let events = AsyncStream<WatchReadingConnectivity.Event>.makeStream(bufferingPolicy: .unbounded)
        let modes = Mutex<[Bool]>([])
        let requestedIdentity = Mutex<UUID?>(nil)

        func run(
            untilDrained: Bool,
            receive: @Sendable (WatchReadingConnectivity.Event) async -> Void
        ) async throws {
            modes.withLock {
                $0.append(untilDrained)
            }
            signals.continuation.yield(.started)
            for await event in events.stream {
                try Task.checkCancellation()
                await receive(event)
                if untilDrained, case .contentDrained = event {
                    return
                }
            }
            try Task.checkCancellation()
        }
    }

    private static let content = Data("""
    {"formatVersion":1,"publicationGeneration":"11111111-1111-4111-8111-111111111111","revision":7,
    "sessionGeneration":"aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa","state":"content",
    "generatedAt":"2026-09-06T00:00:00.000Z","totalEligibleCount":1,
    "items":[{"mangaID":20,"title":"Quiet reading","readingVolume":2,"totalVolumes":12,"coverResourceID":null}]}
    """.utf8)

    private static let redaction = Data("""
    {"formatVersion":1,"publicationGeneration":"11111111-1111-4111-8111-111111111111","revision":8,
    "sessionGeneration":"aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa","state":"redacted",
    "generatedAt":"2026-09-06T00:00:01.000Z","totalEligibleCount":null,"items":[]}
    """.utf8)
}
