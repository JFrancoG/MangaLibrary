import Foundation
import SwiftData
import Synchronization
import Testing
@testable import MangaLibrary

@Suite("Committed reading publication events", .tags(.integration))
struct ReadingPublicationPipelineTests {
    @Test
    func `an unchanged restoration offers watch delivery without another publication or widget reload`() async throws {
        let harness = try Harness()
        defer { harness.removeFiles() }
        let settled = Mutex<[SessionAuthority]>([])
        let pipeline = try harness.pipeline(onProjectionUnchanged: { authorization in
            settled.withLock {
                $0.append(authorization.authority)
            }
        }) { _ in nil }
        _ = try #require(try await pipeline.process(harness.record()))
        let manifest = try harness.storage.read(.snapshot)
        try #require(settled.withLock { $0.isEmpty })

        #expect(try await pipeline.process(harness.record()) == nil)

        #expect(settled.withLock { $0 } == [harness.authority])
        #expect(try harness.storage.read(.snapshot) == manifest)
        #expect(harness.reloads.withLock { $0 } == 1)
    }

    @Test
    func `later committed intent invalidates the earlier ticket in the same session`() throws {
        let harness = try Harness()
        defer { harness.removeFiles() }
        let first = harness.record()
        let second = harness.record()

        #expect(throws: ReadingPublicationError.self) {
            try first.ticket.validate(authority: harness.authority)
        }
        try second.ticket.validate(authority: harness.authority)
        #expect(harness.events.currentEvent()?.ticket === second.ticket)
        #expect(throws: ReadingPublicationError.self) {
            try second.ticket.validate(authority: Self.otherAuthority)
        }
    }

    @Test
    func `late invalidation of the previous account preserves the current intent`() throws {
        let harness = try Harness()
        defer { harness.removeFiles() }
        let first = harness.record()
        harness.gate.activate(Self.otherAuthority)
        let second = harness.events.record(authorization: harness.gate.authorization(for: Self.otherAuthority))

        harness.events.invalidate(authority: harness.authority)

        #expect(harness.events.currentEvent()?.ticket === second.ticket)
        try second.ticket.validate(authority: Self.otherAuthority)
        #expect(throws: ReadingPublicationError.self) {
            try first.ticket.validate(authority: harness.authority)
        }
        harness.events.invalidate(authority: Self.otherAuthority)
        #expect(harness.events.currentEvent() == nil)
        #expect(throws: ReadingPublicationError.self) {
            try second.ticket.validate(authority: Self.otherAuthority)
        }
    }

    @Test
    func `subscription coalesces pending intents and an obsolete lease cannot release its successor`() async throws {
        let harness = try Harness()
        defer { harness.removeFiles() }
        _ = harness.record()
        let latest = harness.record()
        let first = try harness.events.subscribe()
        var iterator = first.stream.makeAsyncIterator()

        #expect(await iterator.next()?.ticket === latest.ticket)
        #expect(throws: ReadingPublicationPipelineError.consumerAlreadyRunning) {
            try harness.events.subscribe()
        }
        _ = harness.record()
        let newest = harness.record()
        #expect(await iterator.next()?.ticket === newest.ticket)
        harness.events.release(first)
        #expect(await iterator.next() == nil)

        let replacement = try harness.events.subscribe()
        defer { harness.events.release(replacement) }
        harness.events.release(first)
        #expect(throws: ReadingPublicationPipelineError.consumerAlreadyRunning) {
            try harness.events.subscribe()
        }
        var replacementIterator = replacement.stream.makeAsyncIterator()
        #expect(await replacementIterator.next()?.ticket === newest.ticket)
    }

    @Test
    func `pipeline reads persisted selection and publishes its prepared cover`() async throws {
        let harness = try Harness()
        defer { harness.removeFiles() }
        let source = try ReadingCoverTestImages.jpeg(pattern: .red)
        let fetched = Mutex<[URL]>([])
        let pipeline = try harness.pipeline { url in
            fetched.withLock {
                $0.append(url)
            }
            return source
        }

        let result = try #require(try await pipeline.process(harness.record()))

        #expect(result.items.map(\.mangaID) == [10])
        #expect(result.items.map(\.readingVolume) == [2])
        #expect(result.items.map(\.title) == ["Persisted reading"])
        #expect(fetched.withLock { $0.map(\.lastPathComponent) } == ["10.jpg", "20.jpg"])
        let identifier = try #require(result.items.first?.coverResourceID)
        #expect(harness.coverReader.read(identifier) != nil)
        #expect(try harness.snapshot()?.items == result.items)
        #expect(harness.reloads.withLock { $0 } == 1)
    }

    @Test
    func `identical cover bytes preserve the manifest revision and widget reload count`() async throws {
        let harness = try Harness()
        defer {
            harness.removeFiles()
        }
        let source = try ReadingCoverTestImages.jpeg(pattern: .red)
        let pipeline = try harness.pipeline { _ in source }
        let baseline = try #require(try await pipeline.process(harness.record()))
        let identifier = try #require(baseline.items.first?.coverResourceID)
        let cover = try #require(harness.coverReader.read(identifier))
        let manifest = try #require(try harness.storage.read(.snapshot))
        #expect(baseline.revision == 1)

        #expect(try await pipeline.process(harness.record()) == nil)

        #expect(try harness.storage.read(.snapshot) == manifest)
        #expect(try harness.snapshot()?.revision == 1)
        #expect(harness.coverReader.read(identifier)?.data == cover.data)
        #expect(harness.reloads.withLock { $0 } == 1)
    }

    @Test
    func `changed bytes at the same cover URL publish the new image pixels`() async throws {
        let harness = try Harness()
        defer {
            harness.removeFiles()
        }
        let red = try ReadingCoverTestImages.jpeg(pattern: .red)
        let blue = try ReadingCoverTestImages.jpeg(pattern: .blue)
        let source = Mutex(red)
        let pipeline = try harness.pipeline { _ in
            source.withLock { $0 }
        }
        let baseline = try #require(try await pipeline.process(harness.record()))
        let originalIdentifier = try #require(baseline.items.first?.coverResourceID)
        let originalCover = try #require(harness.coverReader.read(originalIdentifier))
        let originalImage = try ReadingCoverTestImages.decoded(originalCover.data)
        let originalPixel = try ReadingCoverTestImages.pixel(originalImage, x: 32, y: 16)
        let manifest = try #require(try harness.storage.read(.snapshot))
        #expect(originalPixel[0] > 200 && originalPixel[2] < 60)
        source.withLock {
            $0 = blue
        }

        let updated = try #require(try await pipeline.process(harness.record()))

        let identifier = try #require(updated.items.first?.coverResourceID)
        let cover = try #require(harness.coverReader.read(identifier))
        let image = try ReadingCoverTestImages.decoded(cover.data)
        let pixel = try ReadingCoverTestImages.pixel(image, x: 32, y: 16)
        #expect(pixel[2] > 200 && pixel[0] < 60)
        #expect(identifier != originalIdentifier)
        #expect(updated.revision == 2)
        #expect(try harness.storage.read(.snapshot) != manifest)
        #expect(try harness.snapshot()?.items.first?.coverResourceID == identifier)
        #expect(harness.reloads.withLock { $0 } == 2)
    }

    @Test(arguments: [false, true])
    func `an unavailable cover is retried on the next committed event`(throwsFailure: Bool) async throws {
        let harness = try Harness()
        defer {
            harness.removeFiles()
        }
        let source = try ReadingCoverTestImages.jpeg(pattern: .blue)
        let isAvailable = Mutex(false)
        let pipeline = try harness.pipeline { _ in
            if isAvailable.withLock({ $0 }) {
                return source
            }
            if throwsFailure {
                throw URLError(.notConnectedToInternet)
            }
            return nil
        }
        let baseline = try #require(try await pipeline.process(harness.record()))
        #expect(baseline.items.map(\.mangaID) == [10])
        #expect(baseline.items.first?.coverResourceID == nil)
        #expect(baseline.revision == 1)
        isAvailable.withLock {
            $0 = true
        }

        let updated = try #require(try await pipeline.process(harness.record()))

        let identifier = try #require(updated.items.first?.coverResourceID)
        let cover = try #require(harness.coverReader.read(identifier))
        let image = try ReadingCoverTestImages.decoded(cover.data)
        let pixel = try ReadingCoverTestImages.pixel(image, x: 32, y: 16)
        #expect(pixel[2] > 200 && pixel[0] < 60)
        #expect(updated.revision == 2)
        #expect(try harness.snapshot()?.items.first?.coverResourceID == identifier)
        #expect(harness.reloads.withLock { $0 } == 2)
    }

    @Test
    func `ownership changes for a manga without reading publish a new widget revision`() async throws {
        let harness = try Harness()
        defer { harness.removeFiles() }
        let pipeline = try harness.pipeline { _ in nil }
        let baseline = try #require(try await pipeline.process(harness.record()))
        #expect(baseline.revision == 1)
        #expect(baseline.items.map(\.mangaID) == [10])
        #expect(harness.reloads.withLock { $0 } == 1)

        let mutation = try await harness.mutations.apply(
            CollectionMutationCommand(
                authority: harness.authority,
                mangaID: 20,
                knownTotalVolumes: nil,
                change: .replaceOwnedVolumes([1, 3])
            ),
            authorization: harness.authorization
        )
        #expect(mutation.state.ownedVolumes == [1, 3])
        #expect(mutation.state.readingVolume == nil)
        // This harness supplies the existing post-commit event seam explicitly.
        let updated = try #require(try await pipeline.process(harness.record()))

        #expect(updated.revision == 2)
        #expect(updated.items.map(\.mangaID) == [10])
        #expect(updated.items.map(\.readingVolume) == [2])
        #expect(try harness.snapshot()?.revision == 2)
        #expect(harness.reloads.withLock { $0 } == 2)
    }

    @Test
    func `collection publication is complete when the reading projection is empty`() async throws {
        let harness = try Harness()
        defer { harness.removeFiles() }
        _ = try await harness.mutations.apply(
            CollectionMutationCommand(
                authority: harness.authority,
                mangaID: 10,
                knownTotalVolumes: nil,
                change: .setReadingVolume(nil)
            ),
            authorization: harness.authorization
        )
        let pipeline = try harness.pipeline { _ in nil }

        let published = try #require(try await pipeline.process(harness.record()))

        #expect(published.state == .empty)
        #expect(published.items.isEmpty)
        let reference = try #require(published.collectionReference)
        let bytes = try #require(try harness.storage.read(reference.slot == 0 ? .collection0 : .collection1))
        let collection = try CollectionWidgetSnapshotCodec.decode(bytes)
        #expect(collection.items.map(\.mangaID) == [10, 20])
        #expect(collection.items.map(\.ownedVolumeCount) == [0, 0])
        #expect(collection.items.map(\.isComplete) == [false, false])
        #expect(harness.reloads.withLock { $0 } == 1)
    }

    @Test
    func `unchanged collection retains its slot while damaged bytes are repaired in the other slot`() async throws {
        let harness = try Harness()
        defer { harness.removeFiles() }
        let pipeline = try harness.pipeline { _ in nil }
        let baseline = try #require(try await pipeline.process(harness.record()))
        let reference = try #require(baseline.collectionReference)
        let original = try #require(try harness.storage.read(.collection0))
        let manifest = try harness.storage.read(.snapshot)
        #expect(reference.slot == 0)
        #expect(try await pipeline.process(harness.record()) == nil)
        #expect(try harness.storage.read(.snapshot) == manifest)
        #expect(try harness.storage.read(.collection0) == original)
        #expect(try harness.storage.read(.collection1) == nil)

        let damaged = Data("damaged collection".utf8)
        try harness.storage.replace(.collection0, damaged)
        let repaired = try #require(try await pipeline.process(harness.record()))

        #expect(repaired.revision == 2)
        #expect(repaired.collectionReference?.slot == 1)
        #expect(try harness.storage.read(.collection0) == damaged)
        #expect(try harness.storage.read(.collection1) == original)
        #expect(harness.reloads.withLock { $0 } == 2)
    }

    @Test
    func `a failed manifest keeps its complete collection slot until the retry commits`() async throws {
        let harness = try Harness()
        defer { harness.removeFiles() }
        let pipeline = try harness.pipeline { _ in nil }
        let baseline = try #require(try await pipeline.process(harness.record()))
        #expect(baseline.collectionReference?.slot == 0)
        let original = try harness.storage.read(.collection0)
        let manifest = try harness.storage.read(.snapshot)
        _ = try await harness.mutations.apply(
            CollectionMutationCommand(
                authority: harness.authority,
                mangaID: 20,
                knownTotalVolumes: nil,
                change: .replaceOwnedVolumes([1, 3])
            ),
            authorization: harness.authorization
        )
        harness.failManifest.withLock {
            $0 = true
        }

        await #expect(throws: ReadingSnapshotStorageError.self) {
            try await pipeline.process(harness.record())
        }

        #expect(try harness.storage.read(.snapshot) == manifest)
        #expect(try harness.storage.read(.collection0) == original)
        #expect(harness.reloads.withLock { $0 } == 1)
        harness.failManifest.withLock {
            $0 = false
        }
        let retried = try #require(try await pipeline.process(harness.record()))
        #expect(retried.revision == 3)
        #expect(retried.collectionReference?.slot == 1)
        let bytes = try #require(try harness.storage.read(.collection1))
        let collection = try CollectionWidgetSnapshotCodec.decode(bytes)
        #expect(collection.items.map(\.mangaID) == [10, 20])
        #expect(collection.items.map(\.ownedVolumeCount) == [0, 2])
        #expect(try harness.storage.read(.collection0) == original)
        #expect(harness.reloads.withLock { $0 } == 2)
    }

    @Test
    func `a linked inactive slot cannot redirect collection publication outside shared storage`() async throws {
        let harness = try Harness()
        defer { harness.removeFiles() }
        let pipeline = try harness.pipeline { _ in nil }
        _ = try #require(try await pipeline.process(harness.record()))
        let manifest = try harness.storage.read(.snapshot)
        let protectedURL = harness.directory.appending(path: "protected.json")
        let protectedBytes = Data("unrelated fixture bytes".utf8)
        try protectedBytes.write(to: protectedURL)
        try FileManager.default.createSymbolicLink(
            at: harness.directory.appending(path: "shared/collection-1.json"),
            withDestinationURL: protectedURL
        )
        _ = try await harness.mutations.apply(
            CollectionMutationCommand(
                authority: harness.authority,
                mangaID: 20,
                knownTotalVolumes: nil,
                change: .replaceOwnedVolumes([1])
            ),
            authorization: harness.authorization
        )

        await #expect(throws: ReadingSnapshotStorageError.self) {
            try await pipeline.process(harness.record())
        }

        #expect(try Data(contentsOf: protectedURL) == protectedBytes)
        #expect(try harness.storage.read(.snapshot) == manifest)
        #expect(harness.reloads.withLock { $0 } == 1)
    }

    @Test
    func `superseded intent is rejected before reading covers or writing publisher state`() async throws {
        let harness = try Harness()
        defer { harness.removeFiles() }
        let fetched = Mutex(0)
        let pipeline = try harness.pipeline { _ in
            fetched.withLock {
                $0 += 1
            }
            return nil
        }
        let old = harness.record()
        let current = harness.record()

        await #expect(throws: ReadingPublicationError.self) {
            try await pipeline.process(old)
        }

        #expect(fetched.withLock { $0 } == 0)
        #expect(try harness.storage.read(.publisherState) == nil)
        let published = try #require(try await pipeline.process(current))
        #expect(published.revision == 1)
        #expect(published.items.first?.readingVolume == 2)
    }

    @Test
    func `a mutation during cover preparation prevents the earlier reading from being published`() async throws {
        let harness = try Harness()
        defer { harness.removeFiles() }
        let calls = Mutex(0)
        let pipeline = try harness.pipeline { _ in
            let first = calls.withLock {
                $0 += 1
                return $0 == 1
            }
            if first {
                try await harness.setReading(3)
                _ = harness.record()
            }
            return nil
        }
        let old = harness.record()

        await #expect(throws: ReadingPublicationError.self) {
            try await pipeline.process(old)
        }

        #expect(try harness.storage.read(.publisherState) == nil)
        #expect(try harness.snapshot() == nil)
        let current = try #require(harness.events.currentEvent())
        let result = try #require(try await pipeline.process(current))
        #expect(result.revision == 1)
        #expect(result.items.first?.readingVolume == 3)
        #expect(harness.reloads.withLock { $0 } == 1)
    }

    @Test
    func `account replacement during preparation cannot publish the former account`() async throws {
        let harness = try Harness()
        defer { harness.removeFiles() }
        let calls = Mutex(0)
        let pipeline = try harness.pipeline { _ in
            let first = calls.withLock {
                $0 += 1
                return $0 == 1
            }
            if first {
                harness.gate.activate(Self.otherAuthority)
                harness.events.record(authorization: harness.gate.authorization(for: Self.otherAuthority))
            }
            return nil
        }

        await #expect(throws: (any Error).self) {
            try await pipeline.process(harness.record())
        }

        #expect(try harness.snapshot() == nil)
        #expect(try harness.storage.read(.publisherState) == nil)
        let current = try #require(harness.events.currentEvent())
        let result = try #require(try await pipeline.process(current))
        #expect(result.sessionGeneration == Self.otherAuthority.generation)
        #expect(result.items.map(\.mangaID) == [30])
        #expect(result.items.map(\.readingVolume) == [5])
        #expect(result.revision == 1)
    }

    @Test
    func `cancelled cover preparation preserves persisted reading without publishing`() async throws {
        let harness = try Harness()
        defer { harness.removeFiles() }
        let pipeline = try harness.pipeline { _ in
            throw CancellationError()
        }

        await #expect(throws: CancellationError.self) {
            try await pipeline.process(harness.record())
        }

        #expect(try harness.storage.read(.publisherState) == nil)
        let persisted = try await harness.mutations.readingProjection(authorization: harness.authorization)
        #expect(persisted.items.first?.readingVolume == 2)
    }

    @Test
    func `publication failure preserves the committed mutation and permits its next retry`() async throws {
        let harness = try Harness()
        defer { harness.removeFiles() }
        try await harness.setReading(3)
        harness.failManifest.withLock {
            $0 = true
        }
        let pipeline = try harness.pipeline { _ in nil }
        let event = harness.record()

        await #expect(throws: ReadingSnapshotStorageError.self) {
            try await pipeline.process(event)
        }

        let persisted = try await harness.mutations.readingProjection(authorization: harness.authorization)
        #expect(persisted.items.first?.readingVolume == 3)
        #expect(try ModelContext(harness.container).fetchCount(FetchDescriptor<CollectionOutboxOperation>()) == 1)
        #expect(try harness.snapshot() == nil)
        harness.failManifest.withLock {
            $0 = false
        }
        let retried = try #require(try await pipeline.process(event))
        #expect(retried.items.first?.readingVolume == 3)
        #expect(retried.revision == 2)
    }

    @Test
    func `run coalesces mutations received while preparing and publishes only the newest reading`() async throws {
        let harness = try Harness()
        defer { harness.removeFiles() }
        let signals = AsyncStream<Signal>.makeStream()
        defer { signals.continuation.finish() }
        let suspension = Suspension()
        let calls = Mutex<[String]>([])
        let pipeline = try harness.pipeline(
            onReload: {
                signals.continuation.yield(.published)
            }
        ) { url in
            let first = calls.withLock {
                $0.append(url.lastPathComponent)
                return $0.count == 1
            }
            if first {
                signals.continuation.yield(.started)
                await suspension.wait()
            }
            return nil
        }
        _ = harness.record()

        try await withThrowingTaskGroup(of: Bool.self) { group in
            defer {
                suspension.release()
                group.cancelAll()
            }
            group.addTask {
                defer { signals.continuation.yield(.finished) }
                do {
                    try await pipeline.run()
                    return false
                } catch is CancellationError {
                    return true
                } catch {
                    return false
                }
            }
            var iterator = signals.stream.makeAsyncIterator()
            let first = await iterator.next()
            #expect(first == .started)
            guard first == .started else { return }
            try await harness.setReading(3)
            _ = harness.record()
            try await harness.setReading(4)
            let newest = harness.record()
            suspension.release()
            #expect(await iterator.next() == .published)
            group.cancelAll()
            #expect(try await group.next() == true)
            #expect(harness.events.currentEvent()?.ticket === newest.ticket)
        }

        #expect(try harness.snapshot()?.items.first?.readingVolume == 4)
        #expect(try harness.snapshot()?.revision == 1)
        #expect(harness.reloads.withLock { $0 } == 1)
        #expect(calls.withLock { $0 } == ["10.jpg", "10.jpg", "20.jpg"])
    }

    @Test
    func `run keeps consuming after a publication failure without reverting the committed reading`() async throws {
        let harness = try Harness()
        defer { harness.removeFiles() }
        let signals = AsyncStream<Signal>.makeStream()
        defer { signals.continuation.finish() }
        let pipeline = try harness.pipeline(
            onReload: {
                signals.continuation.yield(.published)
            },
            onManifestFailure: {
                signals.continuation.yield(.failed)
            },
            loadCover: { _ in nil }
        )
        harness.failManifest.withLock {
            $0 = true
        }
        _ = harness.record()

        try await withThrowingTaskGroup(of: Bool.self) { group in
            defer { group.cancelAll() }
            group.addTask {
                defer { signals.continuation.yield(.finished) }
                do {
                    try await pipeline.run()
                    return false
                } catch is CancellationError {
                    return true
                } catch {
                    return false
                }
            }
            var iterator = signals.stream.makeAsyncIterator()
            let first = await iterator.next()
            #expect(first == .failed)
            guard first == .failed else { return }
            let unchanged = try await harness.mutations.readingProjection(authorization: harness.authorization)
            #expect(unchanged.items.first?.readingVolume == 2)
            try await harness.setReading(3)
            harness.failManifest.withLock {
                $0 = false
            }
            _ = harness.record()
            #expect(await iterator.next() == .published)
            group.cancelAll()
            #expect(try await group.next() == true)
        }

        #expect(try harness.snapshot()?.items.first?.readingVolume == 3)
        #expect(try harness.snapshot()?.revision == 2)
        #expect(harness.reloads.withLock { $0 } == 1)
    }

    @Test
    func `cancelled run retains its lease until preparation ends and then allows restart`() async throws {
        let harness = try Harness()
        defer { harness.removeFiles() }
        let signals = AsyncStream<Signal>.makeStream()
        defer { signals.continuation.finish() }
        let suspension = Suspension()
        let pipeline = try harness.pipeline { _ in
            signals.continuation.yield(.started)
            await suspension.wait()
            return nil
        }
        let event = harness.record()

        await withTaskGroup(of: Bool.self) { group in
            defer {
                suspension.release()
                group.cancelAll()
            }
            group.addTask {
                defer { signals.continuation.yield(.finished) }
                do {
                    try await pipeline.run()
                    return false
                } catch is CancellationError {
                    return true
                } catch {
                    return false
                }
            }
            var iterator = signals.stream.makeAsyncIterator()
            let first = await iterator.next()
            #expect(first == .started)
            guard first == .started else { return }
            group.cancelAll()
            await #expect(throws: ReadingPublicationPipelineError.consumerAlreadyRunning) {
                try await pipeline.run()
            }
            suspension.release()
            #expect(await group.next() == true)
        }

        #expect(try harness.snapshot() == nil)
        #expect(harness.events.currentEvent()?.ticket === event.ticket)
        let restarted = try harness.pipeline { _ in
            throw CancellationError()
        }
        await #expect(throws: CancellationError.self) {
            try await restarted.run()
        }
        let subscription = try harness.events.subscribe()
        harness.events.release(subscription)
    }

    @Test
    func `run propagates failed session reconciliation instead of consuming the following account`() async throws {
        let harness = try Harness()
        defer { harness.removeFiles() }
        let calls = Mutex(0)
        let reconciled = Mutex<[SessionAuthority]>([])
        let pipeline = try harness.pipeline(
            reconcileSession: { authority in
                reconciled.withLock {
                    $0.append(authority)
                }
                throw ReconciliationFailure.unavailable
            },
            loadCover: { _ in
                let first = calls.withLock {
                    $0 += 1
                    return $0 == 1
                }
                guard first else { throw CancellationError() }
                harness.gate.activate(Self.otherAuthority)
                harness.events.record(authorization: harness.gate.authorization(for: Self.otherAuthority))
                return nil
            }
        )
        _ = harness.record()

        await #expect(throws: ReadingPublicationSessionReconciliationError.self) {
            try await pipeline.run()
        }

        #expect(reconciled.withLock { $0 } == [harness.authority])
        #expect(calls.withLock { $0 } == 1)
        #expect(try harness.storage.read(.publisherState) == nil)
        let subscription = try harness.events.subscribe()
        harness.events.release(subscription)
    }
}

private extension ReadingPublicationPipelineTests {
    static let authority = SessionAuthority(
        userID: UUID(uuid: (0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 1)),
        generation: UUID(uuid: (0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 2))
    )
    static let otherAuthority = SessionAuthority(
        userID: UUID(uuid: (0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 3)),
        generation: UUID(uuid: (0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 4))
    )

    enum Signal {
        case started
        case published
        case failed
        case finished
    }

    enum ReconciliationFailure: Error {
        case unavailable
    }

    final class Harness: Sendable {
        let directory: URL
        let container: ModelContainer
        let mutations: CollectionMutationActor
        let events = ReadingPublicationEvents()
        let authority = ReadingPublicationPipelineTests.authority
        let gate = SessionCommitGate(activeAuthority: ReadingPublicationPipelineTests.authority)
        let storage: ReadingSnapshotStorage
        let coverReader: ReadingCoverReader
        let reloads = Mutex(0)
        let failManifest = Mutex(false)

        var authorization: SessionCommitAuthorization { gate.authorization(for: authority) }

        init() throws {
            directory = FileManager.default.temporaryDirectory
                .appending(path: UUID().uuidString, directoryHint: .isDirectory)
            storage = try ReadingSnapshotStorage(directory: directory)
            coverReader = ReadingCoverReader(sharedDirectory: directory.appending(path: "shared"))
            container = try MangaLibrarySchema.makeContainer(isStoredInMemoryOnly: true)
            mutations = CollectionMutationActor(modelContainer: container)
            let context = ModelContext(container)
            context.insert(Self.entry(userID: authority.userID, mangaID: 10, reading: 2))
            context.insert(Self.entry(userID: authority.userID, mangaID: 20, reading: nil))
            context.insert(Self.entry(
                userID: ReadingPublicationPipelineTests.otherAuthority.userID,
                mangaID: 30,
                reading: 5
            ))
            try context.save()
        }

        func pipeline(
            onReload: @escaping @Sendable () -> Void = {},
            onManifestFailure: @escaping @Sendable () -> Void = {},
            reconcileSession: @escaping @Sendable (SessionAuthority) async throws -> Void = { _ in },
            onProjectionUnchanged: @escaping @Sendable (SessionCommitAuthorization) async -> Void = { _ in },
            loadCover: @escaping @Sendable (URL) async throws -> Data?
        ) throws -> ReadingPublicationPipeline {
            let observed = ReadingSnapshotStorage(
                read: storage.read,
                replace: { file, data in
                    if file == .snapshot, self.failManifest.withLock({ $0 }) {
                        onManifestFailure()
                        throw ReadingSnapshotStorageError.unavailable
                    }
                    try self.storage.replace(file, data)
                }
            )
            let publisher = ReadingSnapshotPublisher(
                storage: observed,
                now: { Date(timeIntervalSince1970: 1_800_000_000) },
                makeGeneration: { UUID() },
                requestReload: { _ in
                    self.reloads.withLock {
                        $0 += 1
                    }
                    onReload()
                },
                coverStorage: try ReadingCoverStorage(
                    sharedDirectory: directory.appending(path: "shared"),
                    publisherDirectory: directory.appending(path: "publisher")
                )
            )
            return ReadingPublicationPipeline(
                events: events,
                mutations: mutations,
                publisher: publisher,
                loadCover: loadCover,
                reconcileSession: reconcileSession,
                onProjectionUnchanged: onProjectionUnchanged
            )
        }

        func record() -> ReadingPublicationEvent {
            events.record(authorization: authorization)
        }

        func setReading(_ volume: Int64) async throws {
            _ = try await mutations.apply(
                CollectionMutationCommand(
                    authority: authority,
                    mangaID: 10,
                    knownTotalVolumes: nil,
                    change: .setReadingVolume(volume)
                ),
                authorization: authorization
            )
        }

        func snapshot() throws -> ReadingSnapshot? {
            try ReadingSnapshotReader(storage: storage).read()
        }

        func removeFiles() {
            try? FileManager.default.removeItem(at: directory)
        }

        static func entry(userID: UUID, mangaID: Manga.ID, reading: Int64?) -> CollectionEntry {
            CollectionEntry(
                userID: userID,
                mangaID: mangaID,
                state: CollectionSnapshot(
                    ownedVolumes: [],
                    readingVolume: reading,
                    isComplete: false,
                    knownTotalVolumes: 10,
                    isTombstone: false
                ),
                confirmedState: nil,
                mangaSnapshot: CollectionMangaSnapshot(
                    mangaID: mangaID,
                    title: "Persisted reading",
                    titleEnglish: nil,
                    titleJapanese: nil,
                    synopsis: nil,
                    score: 0,
                    status: .unspecified,
                    authors: [],
                    demographics: [],
                    genres: [],
                    themes: [],
                    coverURL: URL(string: "https://covers.invalid/\(mangaID).jpg")
                )
            )
        }
    }

    final class Suspension: Sendable {
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
}
