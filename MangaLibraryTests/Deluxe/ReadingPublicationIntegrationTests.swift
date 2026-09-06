import CoreGraphics
import CryptoKit
import Foundation
import SwiftData
import Synchronization
import Testing
@testable import MangaLibrary

@Suite("Reading publication from real Collection commits", .tags(.integration))
struct ReadingPublicationIntegrationTests {
    @Test
    func `a committed reading requests reload only after its authorized manifest and JPEG are readable`() async throws {
        let fixture = try ReadingPublicationIntegrationFixture()
        defer { fixture.removeFiles() }
        let composition = try fixture.makeComposition()
        let pipeline = fixture.makePipeline(composition)
        #expect(composition.events.currentEvent() == nil)

        _ = try await composition.mutations.apply(fixture.command, authorization: fixture.authorization)

        let committed = try #require(composition.events.currentEvent())
        let result = try #require(try await pipeline.process(committed))

        #expect(result.state == .content)
        #expect(result.items.map(\.mangaID) == [42])
        #expect(result.items.map(\.readingVolume) == [2])
        #expect(result.totalEligibleCount == 1)
        #expect(fixture.loads.withLock { $0 } == 1)
        #expect(fixture.reloads.withLock { $0 } == 1)
        #expect(try fixture.persistedReading() == 2)
        #expect(try ModelContext(fixture.container).fetchCount(FetchDescriptor<CollectionOutboxOperation>()) == 1)
    }

    @Test
    func `an incompatible persisted reading preserves published bytes after restoration`() async throws {
        let fixture = try ReadingPublicationIntegrationFixture()
        defer { fixture.removeFiles() }
        let original = try fixture.makeComposition()
        _ = try await original.mutations.apply(fixture.command, authorization: fixture.authorization)
        let baselineEvent = try #require(original.events.currentEvent())
        _ = try #require(try await fixture.makePipeline(original).process(baselineEvent))
        let before = try fixture.inventory()
        let previousManifest = try #require(try fixture.storage.read(.snapshot))
        let previousFence = try #require(try fixture.storage.read(.fence))
        let previousPublisherState = try #require(try fixture.storage.read(.publisherState))
        #expect(fixture.reloads.withLock { $0 } == 1)
        try fixture.persistIncompatibleReading()

        // A fresh writer models restoration of the historical store, without a cached live model.
        // Session activation is characterized separately; only its authorized event is supplied here.
        let restored = try fixture.makeComposition()
        let authorization = fixture.authorization
        let restoredEvent = try authorization.perform {
            restored.events.record(authorization: authorization)
        }

        await #expect(throws: CollectionReadingProjectionError.incompatibleStoredReading) {
            try await fixture.makePipeline(restored).process(restoredEvent)
        }

        #expect(try fixture.storage.read(.snapshot) == previousManifest)
        #expect(try fixture.storage.read(.fence) == previousFence)
        #expect(try fixture.storage.read(.publisherState) == previousPublisherState)
        #expect(try fixture.inventory() == before)
        #expect(try ReadingSnapshotReader(storage: fixture.storage).read()?.items.first?.readingVolume == 2)
        #expect(fixture.loads.withLock { $0 } == 1)
        #expect(fixture.reloads.withLock { $0 } == 1)
        #expect(try fixture.persistedReading() == 301)
    }
}

private final class ReadingPublicationIntegrationFixture: Sendable {
    let directory: URL
    let container: ModelContainer
    let storage: ReadingSnapshotStorage
    let authority: SessionAuthority
    let gate: SessionCommitGate
    let sourceURL: URL
    let source: Data
    let loads = Mutex(0)
    let reloads = Mutex(0)

    var authorization: SessionCommitAuthorization { gate.authorization(for: authority) }

    var command: CollectionMutationCommand {
        CollectionMutationCommand(
            authority: authority,
            mangaID: 42,
            knownTotalVolumes: 3,
            change: .setReadingVolume(2)
        )
    }

    func makeComposition() throws -> ReadingPublicationComposition {
        try AppComposition.makeReadingPublication(
            modelContainer: container,
            sharedDirectory: directory.appending(path: "shared"),
            publisherDirectory: directory.appending(path: "publisher"),
            now: { Date(timeIntervalSince1970: 1_800_000_000) },
            makeGeneration: {
                UUID(uuid: (0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 9))
            },
            loadCover: { url in
                #expect(url == self.sourceURL)
                self.loads.withLock { $0 += 1 }
                return self.source
            },
            requestReload: { data in
                try self.verifyReadablePublication(atReload: data)
                self.reloads.withLock { $0 += 1 }
            }
        )
    }

    func makePipeline(_ composition: ReadingPublicationComposition) -> ReadingPublicationPipeline {
        ReadingPublicationPipeline(
            events: composition.events,
            mutations: composition.mutations,
            publisher: composition.publisher,
            loadCover: { url in
                #expect(url == self.sourceURL)
                self.loads.withLock { $0 += 1 }
                return self.source
            },
            reconcileSession: { _ in
                throw ReadingPublicationIntegrationFailure.unexpectedSessionReconciliation
            }
        )
    }

    func persistedReading() throws -> Int64? {
        let entries = try ModelContext(container).fetch(FetchDescriptor<CollectionEntry>())
        return try #require(entries.first).readingVolume
    }

    func persistIncompatibleReading() throws {
        let context = ModelContext(container)
        let entry = try #require(try context.fetch(FetchDescriptor<CollectionEntry>()).first)
        entry.apply(Self.state(reading: 301), mangaSnapshot: nil)
        try context.save()
    }

    func inventory() throws -> [String: Data] {
        let enumerator = try #require(FileManager.default.enumerator(
            at: directory,
            includingPropertiesForKeys: [.isRegularFileKey]
        ))
        var result: [String: Data] = [:]
        for case let file as URL in enumerator {
            guard try file.resourceValues(forKeys: [.isRegularFileKey]).isRegularFile == true else { continue }
            let relativePath = String(file.path.dropFirst(directory.path.count + 1))
            result[relativePath] = try Data(contentsOf: file)
        }
        return result
    }

    func removeFiles() {
        try? FileManager.default.removeItem(at: directory)
    }

    private func verifyReadablePublication(atReload data: Data) throws {
        let readable = try #require(try ReadingSnapshotReader(storage: storage).read())
        let fenceBytes = try #require(try storage.read(.fence))
        let fence = try JSONDecoder().decode(SessionFence.self, from: fenceBytes)
        #expect(fence.allowedSessionGeneration == authority.generation)
        #expect(try storage.read(.snapshot) == data)
        #expect(readable.state == .content)
        #expect(readable.items.map(\.mangaID) == [42])
        #expect(readable.items.map(\.title) == ["Persisted reading"])
        #expect(readable.items.map(\.readingVolume) == [2])
        #expect(readable.items.map(\.totalVolumes) == [3])
        #expect(try persistedReading() == 2)
        let identifier = try #require(readable.items.first?.coverResourceID)
        let reader = ReadingCoverReader(sharedDirectory: directory.appending(path: "shared"))
        let cover = try #require(reader.read(identifier))
        let digest = SHA256.hash(data: cover.data).map { String(format: "%02x", $0) }.joined()
        #expect(identifier == digest)
        let image = try ReadingCoverTestImages.decoded(cover.data)
        #expect(image.width == 64)
        #expect(image.height == 32)
        let pixel = try ReadingCoverTestImages.pixel(image, x: 16, y: 16)
        // The synthetic source is red; JPEG and color conversion need not preserve exact channel values.
        #expect(pixel[0] > 200 && pixel[2] < 60)
    }

    private static func state(reading: Int64) -> CollectionSnapshot {
        CollectionSnapshot(
            ownedVolumes: [1],
            readingVolume: reading,
            isComplete: false,
            knownTotalVolumes: 3,
            isTombstone: false
        )
    }

    init() throws {
        let directory = FileManager.default.temporaryDirectory.appending(path: "ReadingPublication-\(UUID())")
        let container = try MangaLibrarySchema.makeContainer(isStoredInMemoryOnly: true)
        let authority = SessionAuthority(
            userID: UUID(uuid: (0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 1)),
            generation: UUID(uuid: (0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 2))
        )
        let sourceURL = try #require(URL(string: "https://covers.example.invalid/42.jpg"))
        let context = ModelContext(container)
        context.insert(CollectionEntry(
            userID: authority.userID,
            mangaID: 42,
            state: Self.state(reading: 1),
            confirmedState: Self.state(reading: 1),
            mangaSnapshot: CollectionMangaSnapshot(
                mangaID: 42,
                title: " Persisted reading ",
                titleEnglish: nil,
                titleJapanese: nil,
                synopsis: nil,
                score: 0,
                status: .unspecified,
                authors: [],
                demographics: [],
                genres: [],
                themes: [],
                coverURL: sourceURL
            )
        ))
        try context.save()
        self.directory = directory
        self.container = container
        self.authority = authority
        self.sourceURL = sourceURL
        source = try ReadingCoverTestImages.jpeg(pattern: .red)
        gate = SessionCommitGate(activeAuthority: authority)
        storage = try ReadingSnapshotStorage(directory: directory)
    }
}

private enum ReadingPublicationIntegrationFailure: Error {
    case unexpectedSessionReconciliation
}
