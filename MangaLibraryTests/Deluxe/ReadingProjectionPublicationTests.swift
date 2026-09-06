import Foundation
import Synchronization
import Testing
@testable import MangaLibrary

@Suite("Budgeted reading publication", .tags(.integration))
struct ReadingProjectionPublicationTests {
    @Test
    func `private and excluded changes do not write reserve or reload`() async throws {
        let harness = try Harness()
        defer { try? FileManager.default.removeItem(at: harness.directory) }
        let initial = harness.projection()
        let publisher = harness.publisher()
        let first = try #require(try await publisher.publish(projection: initial, authorization: harness.authorization))
        #expect(first.items.count < 100)
        let before = try harness.persistedBytes()
        harness.clearEffects()

        var candidates = initial.items
        candidates[0] = item(1, coverURL: URL(string: "https://example.invalid/new-private-source"))
        candidates[99] = item(100, title: "Changed outside the prefix")
        let changed = CollectionReadingProjection(authority: harness.authority, items: candidates)
        let result = try await harness.publisher(time: 1_900_000_000).publish(
            projection: changed,
            coverResourceIDs: [1: "../invalid", 100: String(repeating: "a", count: 64)],
            authorization: harness.authorization
        )

        #expect(result == nil)
        #expect(try harness.persistedBytes() == before)
        #expect(harness.writes.withLock { $0.isEmpty })
        #expect(harness.reloads.withLock { $0.isEmpty })
    }

    @Test
    func `a changed eligible count publishes even when the prefix is identical`() async throws {
        let harness = try Harness()
        defer { try? FileManager.default.removeItem(at: harness.directory) }
        let publisher = harness.publisher()
        let first = try #require(try await publisher.publish(
            projection: harness.projection(),
            authorization: harness.authorization
        ))
        harness.clearEffects()
        let second = try #require(try await publisher.publish(
            projection: harness.projection(count: 101),
            authorization: harness.authorization
        ))

        #expect(second.items == first.items)
        #expect(second.totalEligibleCount == 101)
        #expect(second.revision == 2)
        #expect(harness.reloads.withLock { $0.count } == 1)
        #expect(try harness.persistedSnapshot()?.totalEligibleCount == 101)
    }

    @Test(arguments: VisibleChange.allCases)
    func `visible changes publish a new revision`(change: VisibleChange) async throws {
        let harness = try Harness()
        defer { try? FileManager.default.removeItem(at: harness.directory) }
        let publisher = harness.publisher()
        _ = try await publisher.publish(projection: harness.projection(count: 1), authorization: harness.authorization)
        harness.clearEffects()
        let candidate: CollectionReadingProjection.Item
        var covers: [Manga.ID: String] = [:]
        switch change {
        case .title:
            candidate = item(1, title: "A changed title")
        case .reading:
            candidate = item(1, reading: 2)
        case .total:
            candidate = item(1, total: 4)
        case .cover:
            candidate = item(1)
            covers[1] = String(repeating: "b", count: 64)
        }
        let result = try #require(try await publisher.publish(
            projection: CollectionReadingProjection(authority: harness.authority, items: [candidate]),
            coverResourceIDs: covers,
            authorization: harness.authorization
        ))

        #expect(result.revision == 2)
        #expect(harness.reloads.withLock { $0.count } == 1)
        #expect(try harness.persistedSnapshot()?.revision == 2)
    }

    @Test
    func `revision digit growth preserves the budgeted prefix`() async throws {
        let harness = try Harness()
        defer { try? FileManager.default.removeItem(at: harness.directory) }
        let publisher = harness.publisher()
        _ = try await publisher.publish(projection: harness.projection(), authorization: harness.authorization)
        var state = try JSONDecoder().decode(
            ReadingPublisherState.self,
            from: #require(try harness.storage.read(.publisherState))
        )
        state.lastReservedRevision = 98
        try harness.storage.replace(.publisherState, JSONEncoder().encode(state))
        let at99 = try #require(try await publisher.publish(
            projection: harness.projection(reading: 2),
            authorization: harness.authorization
        ))
        let at100 = try #require(try await publisher.publish(
            projection: harness.projection(reading: 3),
            authorization: harness.authorization
        ))

        #expect(at99.revision == 99)
        #expect(at100.revision == 100)
        #expect(at99.items.map(\.mangaID) == at100.items.map(\.mangaID))
        #expect(at100.items.count < 100)
        let bytes = try #require(try harness.storage.read(.snapshot))
        let context = try PropertyListSerialization.data(
            fromPropertyList: ["readingSnapshot": bytes],
            format: .binary,
            options: 0
        )
        #expect(context.count <= 32_768)
        #expect(at100.totalEligibleCount == 100)
    }

    @Test(arguments: AuthorityMismatch.allCases)
    func `a projection cannot borrow another valid session capability`(mismatch: AuthorityMismatch) async throws {
        let harness = try Harness()
        defer { try? FileManager.default.removeItem(at: harness.directory) }
        _ = try await harness.publisher().publish(
            projection: harness.projection(count: 1),
            authorization: harness.authorization
        )
        let before = try harness.persistedBytes()
        harness.clearEffects()
        let foreign = SessionAuthority(
            userID: mismatch == .user ? UUID() : harness.authority.userID,
            generation: mismatch == .generation ? UUID() : harness.authority.generation
        )
        let projection = CollectionReadingProjection(authority: foreign, items: [item(1)])

        await #expect(throws: ReadingPublicationError.projectionAuthorityMismatch) {
            try await harness.publisher().publish(projection: projection, authorization: harness.authorization)
        }
        #expect(try harness.persistedBytes() == before)
        #expect(harness.writes.withLock { $0.isEmpty })
        #expect(harness.reloads.withLock { $0.isEmpty })
    }

    @Test
    func `a revoked capability cannot publish a previously prepared projection`() async throws {
        let harness = try Harness()
        defer { try? FileManager.default.removeItem(at: harness.directory) }
        let projection = harness.projection(count: 1)
        let authorization = harness.authorization
        _ = try await harness.publisher().publish(projection: projection, authorization: authorization)
        let before = try harness.persistedBytes()
        harness.clearEffects()
        harness.gate.activate(SessionAuthority(userID: harness.authority.userID, generation: UUID()))

        await #expect(throws: (any Error).self) {
            try await harness.publisher().publish(projection: projection, authorization: authorization)
        }
        #expect(try harness.persistedBytes() == before)
        #expect(harness.writes.withLock { $0.isEmpty })
        #expect(harness.reloads.withLock { $0.isEmpty })
    }

    @Test
    func `invalid preparation preserves the previous manifest without a reservation`() async throws {
        let harness = try Harness()
        defer { try? FileManager.default.removeItem(at: harness.directory) }
        _ = try await harness.publisher().publish(
            projection: harness.projection(count: 1),
            authorization: harness.authorization
        )
        let before = try harness.persistedBytes()
        harness.clearEffects()
        var candidates = harness.projection().items
        candidates[99] = item(100, reading: 0)

        await #expect(throws: ReadingSnapshotError.invalidReadingVolume) {
            try await harness.publisher().publish(
                projection: CollectionReadingProjection(authority: harness.authority, items: candidates),
                authorization: harness.authorization
            )
        }
        #expect(try harness.persistedBytes() == before)
        #expect(try harness.persistedSnapshot()?.state == .content)
        #expect(harness.writes.withLock { $0.isEmpty })
        #expect(harness.reloads.withLock { $0.isEmpty })
    }

    @Test
    func `a genuinely empty collection replaces content with empty`() async throws {
        let harness = try Harness()
        defer { try? FileManager.default.removeItem(at: harness.directory) }
        let publisher = harness.publisher()
        _ = try await publisher.publish(projection: harness.projection(count: 1), authorization: harness.authorization)
        let result = try #require(try await publisher.publish(
            projection: CollectionReadingProjection(authority: harness.authority, items: []),
            authorization: harness.authorization
        ))

        #expect(result.state == .empty)
        #expect(result.totalEligibleCount == 0)
        #expect(result.revision == 2)
        #expect(try harness.persistedSnapshot()?.state == .empty)
    }

    @Test
    func `a no op retains pending reload for explicit recovery`() async throws {
        let harness = try Harness()
        defer { try? FileManager.default.removeItem(at: harness.directory) }
        let prepared = try ReadingSnapshot.Item(
            mangaID: 1,
            title: "Reading",
            readingVolume: 1,
            totalVolumes: 3,
            coverResourceID: nil
        )
        _ = try await harness.publisher(failReload: true).publish(
            items: [prepared],
            totalEligibleCount: 1,
            authorization: harness.authorization
        )
        let before = try harness.persistedBytes()
        harness.clearEffects()
        let publisher = harness.publisher()
        let result = try await publisher.publish(
            items: [prepared],
            totalEligibleCount: 1,
            authorization: harness.authorization
        )

        #expect(result == nil)
        #expect(try harness.persistedBytes() == before)
        #expect(harness.writes.withLock { $0.isEmpty })
        #expect(harness.reloads.withLock { $0.isEmpty })

        #expect(try await publisher.recover() == .ready)
        #expect(harness.reloads.withLock { $0.count } == 1)
        #expect(try harness.persistedSnapshot()?.revision == 1)
        #expect(try await publisher.recover() == .ready)
        #expect(harness.reloads.withLock { $0.count } == 1)
    }

    enum VisibleChange: CaseIterable {
        case title, reading, total, cover
    }

    enum AuthorityMismatch: CaseIterable {
        case user, generation
    }

    private func item(
        _ id: Int64,
        title: String = String(repeating: "a", count: 512),
        reading: Int = 1,
        total: Int = 3,
        coverURL: URL? = nil
    ) -> CollectionReadingProjection.Item {
        .init(
            mangaID: id,
            title: title,
            readingVolume: reading,
            totalVolumes: total,
            coverURL: coverURL
        )
    }

    private final class Harness: Sendable {
        let directory: URL
        let storage: ReadingSnapshotStorage
        let authority = SessionAuthority(userID: UUID(), generation: UUID())
        let gate: SessionCommitGate
        let writes = Mutex<[ReadingSnapshotStorage.File]>([])
        let reloads = Mutex<[Data]>([])

        var authorization: SessionCommitAuthorization { gate.authorization(for: authority) }

        init() throws {
            directory = FileManager.default.temporaryDirectory.appending(path: "dx32-\(UUID().uuidString)")
            storage = try ReadingSnapshotStorage(directory: directory)
            gate = SessionCommitGate(activeAuthority: authority)
        }

        func projection(count: Int = 100, reading: Int = 1) -> CollectionReadingProjection {
            CollectionReadingProjection(authority: authority, items: (1...count).map { index in
                .init(
                    mangaID: Int64(index),
                    title: String(repeating: "a", count: 512),
                    readingVolume: index == 1 ? reading : 1,
                    totalVolumes: 3,
                    coverURL: nil
                )
            })
        }

        func publisher(time: TimeInterval = 1_788_652_800, failReload: Bool = false) -> ReadingSnapshotPublisher {
            let observed = ReadingSnapshotStorage(
                read: storage.read,
                replace: { file, data in
                    self.writes.withLock { $0.append(file) }
                    try self.storage.replace(file, data)
                }
            )
            return ReadingSnapshotPublisher(
                storage: observed,
                now: { Date(timeIntervalSince1970: time) },
                makeGeneration: { UUID() },
                requestReload: { data in
                    if failReload {
                        throw ReadingSnapshotStorageError.unavailable
                    }
                    self.reloads.withLock { $0.append(data) }
                }
            )
        }

        func persistedBytes() throws -> [Data?] {
            try [.publisherState, .fence, .snapshot].map(storage.read)
        }

        func persistedSnapshot() throws -> ReadingSnapshot? {
            try ReadingSnapshotReader(storage: storage).read()
        }

        func clearEffects() {
            writes.withLock { $0.removeAll() }
            reloads.withLock { $0.removeAll() }
        }
    }
}
