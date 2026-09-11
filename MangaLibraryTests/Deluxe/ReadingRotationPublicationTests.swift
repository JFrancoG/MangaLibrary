import Foundation
import SwiftData
import Synchronization
import Testing
@testable import MangaLibrary

@Suite("Reading rotation from committed Collection changes", .tags(.integration))
struct ReadingRotationPublicationTests {
    @Test
    func `a local addition without a reading leads the collection before rotating through every manga`() async throws {
        let fixture = try Fixture()
        defer { fixture.removeFiles() }
        let composition = try fixture.composition()
        _ = try await fixture.publishRestored(composition)
        let addedAt = Date(timeIntervalSince1970: 1_800_000_600)
        fixture.clock.withLock {
            $0 = addedAt
        }

        try await fixture.add(4, in: composition)
        _ = try #require(try await fixture.publishLatest(composition))
        let (manifest, collection) = try fixture.readCollection()
        let rotation = CollectionWidgetRotation(snapshot: collection, generatedAt: manifest.generatedAt)
        let offsets: [TimeInterval] = [0, 299, 300, 600, 900, 1_200]

        #expect(collection.items.map(\.mangaID) == [1, 2, 3, 4])
        #expect(offsets.map { rotation.item(at: addedAt.addingTimeInterval($0))?.mangaID } == [4, 4, 1, 2, 3, 4])
        #expect(ReadingWidgetRotation(snapshot: manifest).items(at: addedAt).map(\.mangaID) == [1, 2, 3])
    }

    @Test
    func `coalesced additions keep collection focus through a reading edit and an unordered remote batch`() async throws {
        let fixture = try Fixture()
        defer { fixture.removeFiles() }
        let composition = try fixture.composition()
        _ = try await fixture.publishRestored(composition)
        let addedAt = Date(timeIntervalSince1970: 1_800_000_600)
        fixture.clock.withLock {
            $0 = addedAt
        }

        try await fixture.add(4, in: composition)
        try await fixture.add(5, in: composition)
        try await fixture.edit(2, reading: 3, in: composition)
        try await composition.mutations.importRemote(
            [fixture.remote(3), fixture.remote(1), fixture.remote(2)],
            authorization: fixture.authorization
        )
        _ = try #require(try await fixture.publishLatest(composition))
        let (manifest, collection) = try fixture.readCollection()
        let rotation = CollectionWidgetRotation(snapshot: collection, generatedAt: manifest.generatedAt)

        #expect(collection.items.map(\.mangaID) == [1, 2, 3, 4, 5])
        #expect(rotation.item(at: addedAt)?.mangaID == 5)
        #expect(rotation.item(at: addedAt.addingTimeInterval(300))?.mangaID == 1)
        #expect(ReadingWidgetRotation(snapshot: manifest).items(at: addedAt).map(\.mangaID) == [2, 3, 1])
    }

    @Test
    func `restoration and an equal repeated addition preserve the collection focus and elapsed phase`() async throws {
        let fixture = try Fixture()
        defer { fixture.removeFiles() }
        let original = try fixture.composition()
        _ = try await fixture.publishRestored(original)
        fixture.clock.withLock {
            $0 = Date(timeIntervalSince1970: 1_800_000_600)
        }
        try await fixture.add(4, in: original)
        _ = try #require(try await fixture.publishLatest(original))
        let before = try fixture.bytes()
        fixture.clock.withLock {
            $0 = Date(timeIntervalSince1970: 1_800_003_600)
        }
        let restored = try fixture.composition()

        #expect(try await fixture.publishRestored(restored) == nil)
        try await fixture.add(4, in: restored)
        #expect(try await fixture.publishLatest(restored) == nil)
        let (manifest, collection) = try fixture.readCollection()
        let rotation = CollectionWidgetRotation(snapshot: collection, generatedAt: manifest.generatedAt)

        #expect(try fixture.bytes() == before)
        #expect(manifest.generatedAt == Date(timeIntervalSince1970: 1_800_000_600))
        #expect(rotation.item(at: Date(timeIntervalSince1970: 1_800_000_600))?.mangaID == 4)
        #expect(rotation.item(at: Date(timeIntervalSince1970: 1_800_003_600))?.mangaID == 2)
        #expect(rotation.item(at: Date(timeIntervalSince1970: 1_800_003_900))?.mangaID == 3)
    }

    @Test
    func `deleting the newly added collection focus returns presentation to canonical order`() async throws {
        let fixture = try Fixture()
        defer { fixture.removeFiles() }
        let composition = try fixture.composition()
        try await fixture.add(4, in: composition)
        _ = try #require(try await fixture.publishLatest(composition))
        let (before, added) = try fixture.readCollection()
        let focused = CollectionWidgetRotation(snapshot: added, generatedAt: before.generatedAt)
        #expect(focused.item(at: before.generatedAt)?.mangaID == 4)
        let deletedAt = Date(timeIntervalSince1970: 1_800_000_600)
        fixture.clock.withLock {
            $0 = deletedAt
        }

        _ = try await composition.mutations.apply(
            CollectionMutationCommand(
                authority: fixture.authority,
                mangaID: 4,
                knownTotalVolumes: nil,
                change: .delete
            ),
            authorization: fixture.authorization
        )
        _ = try #require(try await fixture.publishLatest(composition))
        let (manifest, remaining) = try fixture.readCollection()
        let rotation = CollectionWidgetRotation(snapshot: remaining, generatedAt: manifest.generatedAt)

        #expect(remaining.items.map(\.mangaID) == [1, 2, 3])
        #expect(rotation.item(at: deletedAt)?.mangaID == 1)
        #expect(rotation.item(at: deletedAt.addingTimeInterval(300))?.mangaID == 2)
    }

    @Test
    func `a replacement session starts the collection canonically without inheriting an addition focus`() async throws {
        let fixture = try Fixture()
        defer { fixture.removeFiles() }
        let composition = try fixture.composition()
        try await fixture.add(4, in: composition)
        _ = try #require(try await fixture.publishLatest(composition))
        let (before, added) = try fixture.readCollection()
        let focused = CollectionWidgetRotation(snapshot: added, generatedAt: before.generatedAt)
        #expect(focused.item(at: before.generatedAt)?.mangaID == 4)
        let replacement = SessionAuthority(userID: fixture.authority.userID, generation: UUID())
        let restoredAt = Date(timeIntervalSince1970: 1_800_000_600)
        fixture.clock.withLock {
            $0 = restoredAt
        }
        fixture.gate.activate(replacement)
        composition.events.record(authorization: fixture.gate.authorization(for: replacement))

        _ = try #require(try await fixture.publishLatest(composition))
        let (manifest, collection) = try fixture.readCollection()
        let rotation = CollectionWidgetRotation(snapshot: collection, generatedAt: manifest.generatedAt)

        #expect(collection.items.map(\.mangaID) == [1, 2, 3, 4])
        #expect(rotation.item(at: restoredAt)?.mangaID == 1)
        #expect(rotation.item(at: restoredAt.addingTimeInterval(300))?.mangaID == 2)
    }

    @Test
    func `adding a tombstone back leads the collection without claiming a reading edit`() async throws {
        let fixture = try Fixture()
        defer { fixture.removeFiles() }
        let composition = try fixture.composition()
        try await fixture.edit(2, reading: 2, in: composition)
        _ = try #require(try await fixture.publishLatest(composition))
        _ = try await composition.mutations.apply(
            CollectionMutationCommand(
                authority: fixture.authority,
                mangaID: 3,
                knownTotalVolumes: nil,
                change: .delete
            ),
            authorization: fixture.authorization
        )
        _ = try #require(try await fixture.publishLatest(composition))
        let (deletedManifest, deletedCollection) = try fixture.readCollection()
        try #require(deletedCollection.items.map(\.mangaID) == [1, 2])
        let readingsBefore = ReadingWidgetRotation(snapshot: deletedManifest).items(at: deletedManifest.generatedAt)
        try #require(readingsBefore.map(\.mangaID) == [2, 1])
        let addedAt = Date(timeIntervalSince1970: 1_800_000_600)
        fixture.clock.withLock {
            $0 = addedAt
        }

        try await fixture.add(3, in: composition)
        _ = try #require(try await fixture.publishLatest(composition))
        let (manifest, collection) = try fixture.readCollection()
        let rotation = CollectionWidgetRotation(snapshot: collection, generatedAt: manifest.generatedAt)

        #expect(collection.items.map(\.mangaID) == [1, 2, 3])
        #expect(rotation.item(at: addedAt)?.mangaID == 3)
        #expect(rotation.item(at: addedAt.addingTimeInterval(300))?.mangaID == 1)
        #expect(ReadingWidgetRotation(snapshot: manifest).items(at: addedAt).map(\.mangaID) == [2, 3, 1])
    }

    @Test
    func `an unpublished addition then deletion retains the prior collection focus during another edit`() async throws {
        let fixture = try Fixture()
        defer { fixture.removeFiles() }
        let composition = try fixture.composition()
        try await fixture.add(4, in: composition)
        _ = try #require(try await fixture.publishLatest(composition))
        let (before, added) = try fixture.readCollection()
        let focused = CollectionWidgetRotation(snapshot: added, generatedAt: before.generatedAt)
        try #require(focused.item(at: before.generatedAt)?.mangaID == 4)
        let editedAt = Date(timeIntervalSince1970: 1_800_000_600)
        fixture.clock.withLock {
            $0 = editedAt
        }

        try await fixture.add(5, in: composition)
        _ = try await composition.mutations.apply(
            CollectionMutationCommand(
                authority: fixture.authority,
                mangaID: 5,
                knownTotalVolumes: nil,
                change: .delete
            ),
            authorization: fixture.authorization
        )
        try await fixture.own(2, in: composition)
        _ = try #require(try await fixture.publishLatest(composition))
        let (manifest, collection) = try fixture.readCollection()
        let rotation = CollectionWidgetRotation(snapshot: collection, generatedAt: manifest.generatedAt)

        #expect(collection.items.map(\.mangaID) == [1, 2, 3, 4])
        #expect(collection.items.first { $0.mangaID == 2 }?.ownedVolumeCount == 2)
        #expect(rotation.item(at: editedAt)?.mangaID == 4)
        #expect(rotation.item(at: editedAt.addingTimeInterval(300))?.mangaID == 1)
    }

    @Test
    func `a real reading edit publishes its identity while preserving canonical order`() async throws {
        let fixture = try Fixture()
        defer { fixture.removeFiles() }
        let composition = try fixture.composition()
        _ = try await fixture.publishRestored(composition)
        fixture.clock.withLock {
            $0 = Date(timeIntervalSince1970: 1_800_000_600)
        }

        try await fixture.edit(2, reading: 3, in: composition)
        let snapshot = try #require(try await fixture.publishLatest(composition))

        #expect(snapshot.items.map(\.mangaID) == [1, 2, 3])
        #expect(snapshot.items.map(\.readingVolume) == [1, 3, 1])
        #expect(snapshot.preferredStartMangaID == 2)
        #expect(snapshot.generatedAt == Date(timeIntervalSince1970: 1_800_000_600))
        #expect(snapshot.revision == 2)
        #expect(try fixture.readable()?.preferredStartMangaID == 2)
        #expect(fixture.reloads.withLock { $0 } == 2)
    }

    @Test
    func `equal values retain phase while changed ownership publishes and preserves reading focus`() async throws {
        let fixture = try Fixture()
        defer { fixture.removeFiles() }
        let composition = try fixture.composition()
        try await fixture.edit(2, reading: 2, in: composition)
        _ = try await fixture.publishLatest(composition)
        let before = try fixture.bytes()
        fixture.clock.withLock {
            $0 = Date(timeIntervalSince1970: 1_800_003_600)
        }

        try await fixture.edit(1, reading: 1, in: composition)
        #expect(try await fixture.publishLatest(composition) == nil)
        try await fixture.edit(1, reading: 2, in: composition)
        try await fixture.edit(1, reading: 1, in: composition)
        #expect(try await fixture.publishLatest(composition) == nil)

        #expect(try fixture.bytes() == before)
        #expect(try fixture.readable()?.preferredStartMangaID == 2)
        #expect(try fixture.readable()?.generatedAt == Date(timeIntervalSince1970: 1_800_000_000))
        #expect(fixture.reloads.withLock { $0 } == 1)

        try await fixture.own(3, in: composition)
        let ownership = try #require(try await fixture.publishLatest(composition))
        #expect(ownership.revision == 2)
        #expect(ownership.preferredStartMangaID == 2)
        #expect(ownership.generatedAt == Date(timeIntervalSince1970: 1_800_003_600))
        let ownedBytes = try fixture.bytes()
        try await fixture.own(3, in: composition)
        #expect(try await fixture.publishLatest(composition) == nil)
        #expect(try fixture.bytes() == ownedBytes)

        try await composition.mutations.importRemote(
            [fixture.remote(3, title: "Zeta"), fixture.remote(2), fixture.remote(1)],
            authorization: fixture.authorization
        )
        let editorial = try #require(try await fixture.publishLatest(composition))
        #expect(editorial.preferredStartMangaID == 2)
        #expect(editorial.items.map(\.title) == ["Reading 1", "Reading 2", "Zeta"])
        #expect(fixture.reloads.withLock { $0 } == 3)
    }

    @Test
    func `coalescing preserves the latest real reading through ownership and an unordered remote batch`() async throws {
        let fixture = try Fixture()
        defer { fixture.removeFiles() }
        let composition = try fixture.composition()
        try await fixture.edit(1, reading: 2, in: composition)
        try await fixture.edit(2, reading: 3, in: composition)
        try await fixture.own(3, in: composition)
        try await composition.mutations.importRemote(
            [fixture.remote(3), fixture.remote(2), fixture.remote(1)],
            authorization: fixture.authorization
        )

        let snapshot = try #require(try await fixture.publishLatest(composition))

        #expect(snapshot.items.map(\.mangaID) == [1, 2, 3])
        #expect(snapshot.items.map(\.readingVolume) == [2, 3, 1])
        #expect(snapshot.preferredStartMangaID == 2)
        #expect(fixture.reloads.withLock { $0 } == 1)
    }

    @Test
    func `editorial batch changes retain the last published preference without choosing the last remote row`() async throws {
        let fixture = try Fixture()
        defer { fixture.removeFiles() }
        let original = try fixture.composition()
        try await fixture.edit(2, reading: 2, in: original)
        _ = try await fixture.publishLatest(original)
        fixture.clock.withLock {
            $0 = Date(timeIntervalSince1970: 1_800_000_600)
        }
        let restored = try fixture.composition()

        try await restored.mutations.importRemote(
            [fixture.remote(3, title: "Zeta"), fixture.remote(2), fixture.remote(1)],
            authorization: fixture.authorization
        )
        let snapshot = try #require(try await fixture.publishLatest(restored))

        #expect(snapshot.items.map(\.title) == ["Reading 1", "Reading 2", "Zeta"])
        #expect(snapshot.preferredStartMangaID == 2)
        #expect(snapshot.generatedAt == Date(timeIntervalSince1970: 1_800_000_600))
        #expect(snapshot.revision == 2)
    }

    @Test
    func `an edited reading beyond the budget retains its cover and anchor after restoration`() async throws {
        let fixture = try Fixture(count: 100, longTitles: true, coverMangaID: 100)
        defer { fixture.removeFiles() }
        let original = try fixture.composition()
        _ = try await fixture.publishRestored(original)

        try await fixture.edit(100, reading: 2, in: original)
        let snapshot = try #require(try await fixture.publishLatest(original))
        #expect(snapshot.items.map(\.mangaID) == Array(Int64(1)...53) + [100])
        #expect(snapshot.preferredStartMangaID == 100)
        #expect(snapshot.totalEligibleCount == 100)
        let cover = try #require(snapshot.items.last?.coverResourceID)
        let coverReader = ReadingCoverReader(sharedDirectory: fixture.directory.appending(path: "shared"))
        #expect(coverReader.read(cover) != nil)
        let before = try fixture.bytes()
        fixture.clock.withLock {
            $0 = Date(timeIntervalSince1970: 1_800_003_600)
        }
        let restored = try fixture.composition()

        #expect(try await fixture.publishRestored(restored) == nil)
        try await fixture.edit(100, reading: 2, in: restored)
        #expect(try await fixture.publishLatest(restored) == nil)

        #expect(try fixture.bytes() == before)
        #expect(fixture.loads.withLock { $0 } == [100, 100, 100, 100])
        #expect(fixture.reloads.withLock { $0 } == 2)
    }

    @Test
    func `removing the preferred reading clears the focus and empty carries no reading identity`() async throws {
        let fixture = try Fixture(count: 2)
        defer { fixture.removeFiles() }
        let composition = try fixture.composition()
        try await fixture.edit(2, reading: 2, in: composition)
        _ = try await fixture.publishLatest(composition)

        try await fixture.edit(2, reading: nil, in: composition)
        let remaining = try #require(try await fixture.publishLatest(composition))
        #expect(remaining.items.map(\.mangaID) == [1])
        #expect(remaining.preferredStartMangaID == nil)

        try await fixture.edit(1, reading: nil, in: composition)
        let empty = try #require(try await fixture.publishLatest(composition))
        #expect(empty.state == .empty)
        #expect(empty.preferredStartMangaID == nil)
        let emptyBytes = try #require(try fixture.storage.read(.snapshot))
        #expect(String(decoding: emptyBytes, as: UTF8.self).contains("preferredStartMangaID") == false)
    }

    @Test
    func `retirement removes the preferred identity from both the envelope and pending session intent`() async throws {
        let fixture = try Fixture()
        defer { fixture.removeFiles() }
        let composition = try fixture.composition()
        try await fixture.edit(2, reading: 2, in: composition)
        _ = try await fixture.publishLatest(composition)
        #expect(try fixture.readable()?.preferredStartMangaID == 2)

        // These are the session owner's already-characterized retirement hooks; no Keychain is shared here.
        composition.events.invalidate(authority: fixture.authority)
        let retirement = try await composition.publisher.close(sessionGeneration: fixture.authority.generation)
        try await composition.publisher.finishRetirement(retirement)

        let bytes = try #require(try fixture.storage.read(.snapshot))
        let redacted = try ReadingSnapshotCodec.decode(bytes)
        #expect(redacted.state == .redacted)
        #expect(redacted.preferredStartMangaID == nil)
        #expect(String(decoding: bytes, as: UTF8.self).contains("preferredStartMangaID") == false)
        #expect(composition.events.currentEvent() == nil)
        #expect(try ReadingSnapshotReader(storage: fixture.storage).readResult() == .redacted)
    }

    @Test
    func `a replacement session does not inherit the previous sessions preferred reading`() async throws {
        let fixture = try Fixture()
        defer { fixture.removeFiles() }
        let composition = try fixture.composition()
        try await fixture.edit(2, reading: 2, in: composition)
        _ = try await fixture.publishLatest(composition)
        #expect(try fixture.readable()?.preferredStartMangaID == 2)
        let replacement = SessionAuthority(userID: fixture.authority.userID, generation: UUID())
        fixture.gate.activate(replacement)
        composition.events.record(authorization: fixture.gate.authorization(for: replacement))

        let snapshot = try #require(try await fixture.publishLatest(composition))

        #expect(snapshot.sessionGeneration == replacement.generation)
        #expect(snapshot.items.map(\.mangaID) == [1, 2, 3])
        #expect(snapshot.preferredStartMangaID == nil)
    }

    @Test(arguments: [false, true])
    func `reviving a tombstone through ownership or completeness does not claim a reading edit`(
        complete: Bool
    ) async throws {
        let fixture = try Fixture()
        defer { fixture.removeFiles() }
        let composition = try fixture.composition()
        try await fixture.edit(2, reading: 2, in: composition)
        _ = try await fixture.publishLatest(composition)
        _ = try await composition.mutations.apply(
            CollectionMutationCommand(
                authority: fixture.authority,
                mangaID: 1,
                knownTotalVolumes: nil,
                change: .delete
            ),
            authorization: fixture.authorization
        )
        let deleted = try #require(try await fixture.publishLatest(composition))
        #expect(deleted.items.map(\.mangaID) == [2, 3])
        #expect(deleted.preferredStartMangaID == 2)
        fixture.clock.withLock {
            $0 = Date(timeIntervalSince1970: 1_800_000_600)
        }

        _ = try await composition.mutations.apply(
            CollectionMutationCommand(
                authority: fixture.authority,
                mangaID: 1,
                knownTotalVolumes: nil,
                change: complete ? .setComplete(true) : .replaceOwnedVolumes([1, 2])
            ),
            authorization: fixture.authorization
        )
        let revived = try #require(try await fixture.publishLatest(composition))

        #expect(revived.items.map(\.mangaID) == [1, 2, 3])
        #expect(revived.items.map(\.readingVolume) == [1, 2, 1])
        #expect(revived.preferredStartMangaID == 2)
        #expect(revived.generatedAt == Date(timeIntervalSince1970: 1_800_000_600))
        #expect(revived.revision == 3)
    }
}

private extension ReadingRotationPublicationTests {
    final class Fixture: Sendable {
        let directory: URL
        let container: ModelContainer
        let storage: ReadingSnapshotStorage
        let authority = SessionAuthority(userID: UUID(), generation: UUID())
        let gate: SessionCommitGate
        let clock = Mutex(Date(timeIntervalSince1970: 1_800_000_000))
        let reloads = Mutex(0)
        let loads = Mutex<[Int64]>([])
        let coverMangaID: Int64?
        let source: Data
        let longTitles: Bool

        var authorization: SessionCommitAuthorization { gate.authorization(for: authority) }

        init(count: Int = 3, longTitles: Bool = false, coverMangaID: Int64? = nil) throws {
            directory = FileManager.default.temporaryDirectory.appending(path: "ReadingRotation-\(UUID())")
            container = try MangaLibrarySchema.makeContainer(isStoredInMemoryOnly: true)
            storage = try ReadingSnapshotStorage(directory: directory)
            gate = SessionCommitGate(activeAuthority: authority)
            self.coverMangaID = coverMangaID
            self.longTitles = longTitles
            source = try ReadingCoverTestImages.jpeg(pattern: .red)
            let context = ModelContext(container)
            let state = CollectionSnapshot(
                ownedVolumes: [1],
                readingVolume: 1,
                isComplete: false,
                knownTotalVolumes: 3,
                isTombstone: false
            )
            for identifier in Int64(1)...Int64(count) {
                context.insert(CollectionEntry(
                    userID: authority.userID,
                    mangaID: identifier,
                    state: state,
                    confirmedState: state,
                    mangaSnapshot: CollectionMangaSnapshot(manga: manga(identifier))
                ))
            }
            try context.save()
        }

        func composition() throws -> ReadingPublicationComposition {
            try AppComposition.makeReadingPublication(
                modelContainer: container,
                sharedDirectory: directory.appending(path: "shared"),
                publisherDirectory: directory.appending(path: "publisher"),
                now: { self.clock.withLock { $0 } },
                makeGeneration: { UUID() },
                loadCover: { url in
                    self.loads.withLock {
                        $0.append(Int64(url.lastPathComponent) ?? 0)
                    }
                    return self.source
                },
                requestReload: { data in
                    do {
                        #expect(try self.storage.read(.snapshot) == data)
                    } catch {
                        Issue.record(error)
                    }
                    self.reloads.withLock {
                        $0 += 1
                    }
                }
            )
        }

        func publishRestored(_ composition: ReadingPublicationComposition) async throws -> ReadingSnapshot? {
            // Supply the authorized restore signal, without opening the live session or touching Keychain.
            composition.events.record(authorization: authorization)
            return try await publishLatest(composition)
        }

        func publishLatest(_ composition: ReadingPublicationComposition) async throws -> ReadingSnapshot? {
            let event = try #require(composition.events.currentEvent())
            let pipeline = ReadingPublicationPipeline(
                events: composition.events,
                mutations: composition.mutations,
                publisher: composition.publisher,
                loadCover: composition.loadCover,
                reconcileSession: { _ in
                    throw Failure.unexpectedReconciliation
                }
            )
            return try await pipeline.process(event)
        }

        func edit(_ mangaID: Int64, reading: Int64?, in composition: ReadingPublicationComposition) async throws {
            _ = try await composition.mutations.apply(
                CollectionMutationCommand(
                    authority: authority,
                    mangaID: mangaID,
                    knownTotalVolumes: nil,
                    change: .setReadingVolume(reading)
                ),
                authorization: authorization
            )
        }

        func own(_ mangaID: Int64, in composition: ReadingPublicationComposition) async throws {
            _ = try await composition.mutations.apply(
                CollectionMutationCommand(
                    authority: authority,
                    mangaID: mangaID,
                    knownTotalVolumes: nil,
                    change: .replaceOwnedVolumes([1, 2])
                ),
                authorization: authorization
            )
        }

        func add(_ mangaID: Int64, in composition: ReadingPublicationComposition) async throws {
            _ = try await composition.mutations.apply(
                CollectionMutationCommand(
                    authority: authority,
                    mangaID: mangaID,
                    mangaSnapshot: CollectionMangaSnapshot(manga: manga(mangaID)),
                    knownTotalVolumes: 3,
                    change: .replaceOwnedVolumes([])
                ),
                authorization: authorization
            )
        }

        func remote(_ mangaID: Int64, title: String? = nil) -> CollectionRemoteEntry {
            CollectionRemoteEntry(
                remoteID: UUID(),
                manga: manga(mangaID, title: title),
                ownedVolumes: [1],
                readingVolume: 1,
                isComplete: false,
                reportedTotalVolumes: 3
            )
        }

        func readable() throws -> ReadingSnapshot? {
            try ReadingSnapshotReader(storage: storage).read()
        }

        func readCollection() throws -> (ReadingSnapshot, CollectionWidgetSnapshot) {
            let reader = CollectionWidgetReader(
                readFence: {
                    try self.storage.read(.fence)
                },
                readSnapshot: {
                    try self.storage.read(.snapshot)
                },
                readCollection: {
                    try self.storage.read($0 == 0 ? .collection0 : .collection1)
                }
            )
            guard case let .snapshot(manifest, collection) = try reader.readResult() else {
                throw Failure.unavailableCollection
            }
            return (manifest, collection)
        }

        func bytes() throws -> [Data?] {
            try [.publisherState, .fence, .snapshot].map(storage.read)
        }

        func removeFiles() {
            try? FileManager.default.removeItem(at: directory)
        }

        private func manga(_ identifier: Int64, title: String? = nil) -> Manga {
            Manga(
                id: identifier,
                title: title ?? (longTitles ? String(repeating: "a", count: 512) : "Reading \(identifier)"),
                titleEnglish: nil,
                titleJapanese: nil,
                synopsis: nil,
                score: 8,
                status: .publishing,
                authors: [],
                demographics: [],
                genres: [],
                themes: [],
                coverURL: identifier == coverMangaID ? URL(string: "https://covers.invalid/\(identifier)") : nil
            )
        }
    }

    enum Failure: Error {
        case unexpectedReconciliation
        case unavailableCollection
    }
}
