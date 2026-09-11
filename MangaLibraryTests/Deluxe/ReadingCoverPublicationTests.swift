import Foundation
import Synchronization
import Testing
@testable import MangaLibrary

@Suite("Cover publication ordering", .tags(.integration))
struct ReadingCoverPublicationTests {
    @Test(arguments: [false, true])
    func `a newer commit prevents stale cover admission and manifest replacement`(afterReservation: Bool) async throws {
        let harness = try Harness()
        defer { try? FileManager.default.removeItem(at: harness.directory) }
        let events = ReadingPublicationEvents()
        let authorization = harness.authorization
        let old = try authorization.perform {
            events.record(authorization: authorization)
        }
        let armed = Mutex(afterReservation)
        let publisher = try harness.publisher(onStateWrite: { data in
            let state = try JSONDecoder().decode(ReadingPublisherState.self, from: data)
            guard case .publication = state.intent else { return }
            let supersede = armed.withLock { armed in
                let result = armed
                armed = false
                return result
            }
            if supersede {
                _ = try authorization.perform {
                    events.record(authorization: authorization)
                }
            }
        })
        if !afterReservation {
            _ = try authorization.perform {
                events.record(authorization: authorization)
            }
        }
        let cover = try resource()

        await #expect(throws: ReadingPublicationError.self) {
            try await publisher.publish(
                projection: harness.projection(),
                preparedCovers: [1: cover],
                authorization: old.authorization,
                ticket: old.ticket
            )
        }

        #expect(harness.coverWrites.withLock { $0.isEmpty })
        #expect(try harness.snapshotStorage.read(.snapshot) == nil)
        #expect(harness.reader.read(cover.identifier) == nil)
        #expect(harness.reloads.withLock { $0 == 0 })
        let current = try #require(events.currentEvent())
        let result = try #require(try await publisher.publish(
            projection: harness.projection(reading: 2),
            preparedCovers: [1: cover],
            authorization: current.authorization,
            ticket: current.ticket
        ))
        #expect(result.revision == (afterReservation ? 2 : 1))
        #expect(result.items.first?.readingVolume == 2)
    }

    @Test
    func `a changed projection settles committed admission before replacing its manifest`() async throws {
        let harness = try Harness()
        defer { try? FileManager.default.removeItem(at: harness.directory) }
        let cover = try resource()
        let publisher = try harness.publisher()
        harness.failCleanup.withLock {
            $0 = true
        }
        _ = try await publisher.publish(
            projection: harness.projection(),
            preparedCovers: [1: cover],
            authorization: harness.authorization
        )
        harness.failCleanup.withLock {
            $0 = false
        }

        let changed = try #require(try await publisher.publish(
            projection: harness.projection(reading: 2),
            preparedCovers: [1: cover],
            authorization: harness.authorization
        ))
        let replacement = try resource(blue: true)
        let next = try #require(try await publisher.publish(
            projection: harness.projection(reading: 3),
            preparedCovers: [1: replacement],
            authorization: harness.authorization
        ))

        #expect(changed.items.first?.coverResourceID == cover.identifier)
        #expect(changed.revision == 2)
        #expect(next.items.first?.coverResourceID == replacement.identifier)
        #expect(harness.reader.read(replacement.identifier) == replacement)
    }

    @Test
    func `quota can preserve a partial cover no op without finalizing its pending journal`() async throws {
        let harness = try Harness()
        defer { try? FileManager.default.removeItem(at: harness.directory) }
        let first = try resource()
        let second = try resource(blue: true)
        let publisher = try harness.publisher()
        harness.failCleanup.withLock {
            $0 = true
        }
        _ = try await publisher.publish(
            projection: harness.projection(count: 2),
            preparedCovers: [1: first],
            authorization: harness.authorization
        )
        harness.failCleanup.withLock {
            $0 = false
        }
        harness.quotaReached.withLock {
            $0 = true
        }
        harness.clearEffects()
        let previous = try harness.snapshotStorage.read(.snapshot)

        let repeated = try await publisher.publish(
            projection: harness.projection(count: 2),
            preparedCovers: [1: first, 2: second],
            authorization: harness.authorization
        )

        #expect(repeated == nil)
        #expect(try harness.snapshotStorage.read(.snapshot) == previous)
        #expect(harness.coverWrites.withLock { $0.isEmpty })
        #expect(harness.snapshotWrites.withLock { $0.isEmpty })
        #expect(harness.reloads.withLock { $0 == 0 })
        #expect(try await publisher.recover() == .ready)
        #expect(!harness.coverWrites.withLock { $0.isEmpty })
    }

    @Test
    func `an identical manifest does not rewrite covers when admission finalization is pending`() async throws {
        let harness = try Harness()
        defer { try? FileManager.default.removeItem(at: harness.directory) }
        let cover = try resource()
        let publisher = try harness.publisher()
        harness.failCleanup.withLock {
            $0 = true
        }
        _ = try await publisher.publish(
            projection: harness.projection(),
            preparedCovers: [1: cover],
            authorization: harness.authorization
        )
        let previous = try harness.snapshotStorage.read(.snapshot)
        harness.failCleanup.withLock {
            $0 = false
        }
        harness.clearEffects()

        let repeated = try await publisher.publish(
            projection: harness.projection(),
            preparedCovers: [1: cover],
            authorization: harness.authorization
        )

        #expect(repeated == nil)
        #expect(try harness.snapshotStorage.read(.snapshot) == previous)
        #expect(harness.coverWrites.withLock { $0.isEmpty })
        #expect(harness.snapshotWrites.withLock { $0.isEmpty })
        #expect(harness.reloads.withLock { $0 == 0 })
        #expect(try await publisher.recover() == .ready)
        #expect(!harness.coverWrites.withLock { $0.isEmpty })
    }

    @Test
    func `resources exist before their manifest and an identical publication performs no writes`() async throws {
        let harness = try Harness()
        defer { try? FileManager.default.removeItem(at: harness.directory) }
        let cover = try resource()
        let publisher = try harness.publisher()
        let first = try #require(try await publisher.publish(
            projection: harness.projection(),
            preparedCovers: [1: cover],
            authorization: harness.authorization
        ))

        #expect(first.items.first?.coverResourceID == cover.identifier)
        #expect(harness.manifestChecks.withLock { $0 == [true] })
        #expect(harness.reader.read(cover.identifier)?.data == cover.data)
        let before = try harness.snapshotStorage.read(.snapshot)
        harness.clearEffects()
        let repeated = try await harness.publisher().publish(
            projection: harness.projection(),
            preparedCovers: [1: cover],
            authorization: harness.authorization
        )

        #expect(repeated == nil)
        #expect(try harness.snapshotStorage.read(.snapshot) == before)
        #expect(harness.coverWrites.withLock { $0.isEmpty })
        #expect(harness.snapshotWrites.withLock { $0.isEmpty })
        #expect(harness.reloads.withLock { $0 == 0 })
    }

    @Test
    func `excluded candidates never consume durable cover admission`() async throws {
        let harness = try Harness()
        defer { try? FileManager.default.removeItem(at: harness.directory) }
        let included = try resource()
        let excluded = try resource(blue: true)
        let result = try #require(try await harness.publisher().publish(
            projection: harness.projection(count: 100, title: String(repeating: "a", count: 512)),
            preparedCovers: [1: included, 100: excluded],
            authorization: harness.authorization
        ))

        #expect(result.totalEligibleCount == 100)
        #expect(result.items.last?.mangaID != 100)
        #expect(harness.reader.read(included.identifier)?.data == included.data)
        #expect(!FileManager.default.fileExists(atPath: harness.coverURL(excluded.identifier).path))
        #expect(!harness.coverWrites.withLock { $0.contains { $0.contains(excluded.identifier) } })
    }

    @Test
    func `exhausted cover quota selects a placeholder before the commit`() async throws {
        let harness = try Harness(fullQuota: true)
        defer { try? FileManager.default.removeItem(at: harness.directory) }
        let cover = try resource()
        let result = try #require(try await harness.publisher().publish(
            projection: harness.projection(),
            preparedCovers: [1: cover],
            authorization: harness.authorization
        ))

        #expect(result.state == .content)
        #expect(result.items.first?.coverResourceID == nil)
        #expect(result.revision == 1)
        #expect(harness.coverWrites.withLock { $0.isEmpty })
        #expect(harness.reader.read(cover.identifier) == nil)
    }

    @Test
    func `a resource write failure preserves the manifest and consumes its reservation`() async throws {
        let harness = try Harness()
        defer { try? FileManager.default.removeItem(at: harness.directory) }
        let publisher = try harness.publisher()
        _ = try await publisher.publish(
            projection: harness.projection(),
            preparedCovers: [:],
            authorization: harness.authorization
        )
        let previous = try harness.snapshotStorage.read(.snapshot)
        let cover = try resource()
        harness.failResource.withLock {
            $0 = true
        }

        await #expect(throws: (any Error).self) {
            try await publisher.publish(
                projection: harness.projection(reading: 2),
                preparedCovers: [1: cover],
                authorization: harness.authorization
            )
        }
        #expect(try harness.snapshotStorage.read(.snapshot) == previous)
        #expect(try harness.persistedSnapshot()?.revision == 1)
        harness.failResource.withLock {
            $0 = false
        }
        #expect(try await publisher.recover() == .ready)
        let next = try #require(try await publisher.publish(
            projection: harness.projection(reading: 2),
            preparedCovers: [1: cover],
            authorization: harness.authorization
        ))

        #expect(next.revision == 3)
        #expect(harness.reader.read(cover.identifier)?.data == cover.data)
    }

    @Test
    func `resources marked for retention survive a failed manifest and later logout`() async throws {
        let harness = try Harness()
        defer { try? FileManager.default.removeItem(at: harness.directory) }
        let publisher = try harness.publisher()
        _ = try await publisher.publish(
            projection: harness.projection(),
            preparedCovers: [:],
            authorization: harness.authorization
        )
        let previous = try harness.snapshotStorage.read(.snapshot)
        let cover = try resource()
        harness.failManifest.withLock {
            $0 = true
        }

        await #expect(throws: (any Error).self) {
            try await publisher.publish(
                projection: harness.projection(reading: 2),
                preparedCovers: [1: cover],
                authorization: harness.authorization
            )
        }
        #expect(try harness.snapshotStorage.read(.snapshot) == previous)
        #expect(harness.reader.read(cover.identifier)?.data == cover.data)
        harness.failManifest.withLock {
            $0 = false
        }
        #expect(try await publisher.recover() == .ready)
        _ = try await publisher.publish(
            projection: harness.projection(reading: 3),
            preparedCovers: [:],
            authorization: harness.authorization
        )
        let logout = try #require(harness.gate.suspendForLogout(harness.authority))
        let retirement = try await publisher.close(authorization: logout)
        try await publisher.finishRetirement(retirement)
        _ = try await harness.publisher().recover()

        let redacted = try #require(try harness.snapshotStorage.read(.snapshot))
        #expect(try ReadingSnapshotCodec.decode(redacted).state == .redacted)
        #expect(try harness.persistedSnapshot() == nil)
        #expect(harness.reader.read(cover.identifier)?.data == cover.data)
    }

    @Test
    func `revoked authority fails before any cover admission`() async throws {
        let harness = try Harness()
        defer { try? FileManager.default.removeItem(at: harness.directory) }
        let authorization = harness.authorization
        let projection = harness.projection()
        let cover = try resource()
        harness.gate.activate(SessionAuthority(userID: harness.authority.userID, generation: UUID()))

        await #expect(throws: (any Error).self) {
            try await harness.publisher().publish(
                projection: projection,
                preparedCovers: [1: cover],
                authorization: authorization
            )
        }

        #expect(harness.coverWrites.withLock { $0.isEmpty })
        #expect(harness.snapshotWrites.withLock { $0.isEmpty })
        #expect(harness.reader.read(cover.identifier) == nil)
    }

    @Test
    func `inaccessible cover recovery cannot prevent the session fence from closing`() async throws {
        let harness = try Harness()
        defer { try? FileManager.default.removeItem(at: harness.directory) }
        let publisher = try harness.publisher()
        _ = try await publisher.publish(
            projection: harness.projection(),
            preparedCovers: [1: resource()],
            authorization: harness.authorization
        )
        harness.failCoverRead.withLock {
            $0 = true
        }
        #expect(try await publisher.recover() == .ready)
        #expect(harness.failedCoverReads.withLock { $0 > 0 })
        let logout = try #require(harness.gate.suspendForLogout(harness.authority))

        _ = try await publisher.close(authorization: logout)

        #expect(try harness.persistedSnapshot() == nil)
    }

    private func resource(blue: Bool = false) throws -> ReadingCoverResource {
        try #require(ReadingCoverResource(jpegData: try ReadingCoverTestImages.jpeg(pattern: blue ? .blue : .red)))
    }

    private final class Harness: Sendable {
        let directory: URL
        let shared: URL
        let privateDirectory: URL
        let snapshotStorage: ReadingSnapshotStorage
        let reader: ReadingCoverReader
        let authority = SessionAuthority(userID: UUID(), generation: UUID())
        let gate: SessionCommitGate
        let fullQuota: Bool
        let coverWrites = Mutex<[String]>([])
        let snapshotWrites = Mutex<[ReadingSnapshotStorage.File]>([])
        let manifestChecks = Mutex<[Bool]>([])
        let reloads = Mutex(0)
        let failResource = Mutex(false)
        let failManifest = Mutex(false)
        let failCoverRead = Mutex(false)
        let failCleanup = Mutex(false)
        let quotaReached = Mutex(false)
        let failedCoverReads = Mutex(0)

        var authorization: SessionCommitAuthorization { gate.authorization(for: authority) }

        init(fullQuota: Bool = false) throws {
            directory = FileManager.default.temporaryDirectory.appending(path: "dx33-publish-\(UUID().uuidString)")
            shared = directory.appending(path: "shared")
            privateDirectory = directory.appending(path: "publisher")
            snapshotStorage = try ReadingSnapshotStorage(sharedDirectory: shared, publisherDirectory: privateDirectory)
            reader = ReadingCoverReader(sharedDirectory: shared)
            gate = SessionCommitGate(activeAuthority: authority)
            self.fullQuota = fullQuota
        }

        func projection(count: Int = 1, reading: Int = 1, title: String = "Reading") -> CollectionReadingProjection {
            CollectionReadingProjection(authority: authority, items: (1...count).map { index in
                .init(
                    mangaID: Int64(index),
                    title: title,
                    readingVolume: reading,
                    totalVolumes: 3,
                    coverURL: nil
                )
            })
        }

        func publisher(
            onStateWrite: @escaping @Sendable (Data) throws -> Void = { _ in }
        ) throws -> ReadingSnapshotPublisher {
            let base = ReadingCoverStorage.Effects.live
            let effects = ReadingCoverStorage.Effects(
                read: { url, limit in
                    if self.failCoverRead.withLock({ $0 }) {
                        self.failedCoverReads.withLock {
                            $0 += 1
                        }
                        throw ReadingCoverStorageError.unavailable
                    }
                    return try base.read(url, limit)
                },
                writeExclusive: { url, data in
                    self.coverWrites.withLock {
                        $0.append(url.lastPathComponent)
                    }
                    if url.pathExtension != "json", self.failResource.withLock({ $0 }) {
                        throw ReadingCoverStorageError.unavailable
                    }
                    try base.writeExclusive(url, data)
                },
                promoteExclusive: { from, to in
                    self.coverWrites.withLock {
                        $0.append(to.lastPathComponent)
                    }
                    try base.promoteExclusive(from, to)
                },
                remove: { url in
                    self.coverWrites.withLock {
                        $0.append(url.lastPathComponent)
                    }
                    if self.failCleanup.withLock({ $0 }) {
                        throw ReadingCoverStorageError.unavailable
                    }
                    try base.remove(url)
                },
                inventory: { roots in
                    self.fullQuota || self.quotaReached.withLock({ $0 }) ? 8_388_608 : try base.inventory(roots)
                }
            )
            let covers = try ReadingCoverStorage(
                sharedDirectory: shared,
                publisherDirectory: privateDirectory,
                effects: effects
            )
            let observed = ReadingSnapshotStorage(
                read: snapshotStorage.read,
                replace: { file, data in
                    self.snapshotWrites.withLock {
                        $0.append(file)
                    }
                    if file == .snapshot {
                        if self.failManifest.withLock({ $0 }) {
                            throw ReadingSnapshotStorageError.unavailable
                        }
                        let manifest = try ReadingSnapshotCodec.decode(data)
                        let valid = manifest.items.compactMap(\.coverResourceID).allSatisfy {
                            self.reader.read($0) != nil
                        }
                        self.manifestChecks.withLock {
                            $0.append(valid)
                        }
                    }
                    try self.snapshotStorage.replace(file, data)
                    if file == .publisherState {
                        try onStateWrite(data)
                    }
                }
            )
            return ReadingSnapshotPublisher(
                storage: observed,
                now: { Date(timeIntervalSince1970: 1_788_652_800) },
                makeGeneration: { UUID() },
                requestReload: { _ in
                    self.reloads.withLock {
                        $0 += 1
                    }
                },
                coverStorage: covers
            )
        }

        func coverURL(_ identifier: String) -> URL {
            shared.appending(path: "covers/\(identifier).jpg")
        }

        func persistedSnapshot() throws -> ReadingSnapshot? {
            try ReadingSnapshotReader(storage: snapshotStorage).read()
        }

        func clearEffects() {
            coverWrites.withLock {
                $0.removeAll()
            }
            snapshotWrites.withLock {
                $0.removeAll()
            }
            manifestChecks.withLock {
                $0.removeAll()
            }
            reloads.withLock {
                $0 = 0
            }
        }
    }
}
